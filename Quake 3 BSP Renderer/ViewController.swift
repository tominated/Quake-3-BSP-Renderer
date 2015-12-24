//
//  ViewController.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import GLKit
import MetalKit

struct Uniforms {
    var modelMatrix : GLKMatrix4
    var viewMatrix : GLKMatrix4
    var projectionMatrix : GLKMatrix4
}

class ViewController: UIViewController {
    // Main metal objects
    let metalLayer = CAMetalLayer()
    let device = MTLCreateSystemDefaultDevice()!
    
    var commandQueue : MTLCommandQueue! = nil
    var pipeline : MTLRenderPipelineState! = nil
    
    // Resources
    var uniformBuffer : MTLBuffer! = nil
    var mapMesh : MapMesh! = nil
    var uniforms : Uniforms! = nil
    
    let sampleCount = 4
    
    // Transients
    var timer : CADisplayLink! = nil
    var lastFrameTimestamp : CFTimeInterval = 0.0
    var elapsedTime : CFTimeInterval = 0.0
    
    var aspect : Float = 0.0
    var fov : Float = GLKMathDegreesToRadians(65.0)
    var camera : Camera = Camera()
    
    func loadMap() {
        let filename = NSBundle.mainBundle().pathForResource("q3dm3", ofType: "bsp")!
        let binaryData = NSData(contentsOfFile: filename)!
        let bsp = BSPMap.init(data: binaryData)
        
        mapMesh = MapMesh(device: self.device, bsp: bsp)
    }
    
    func initializeMetal() {
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        
        view.layer.addSublayer(metalLayer)
        
        commandQueue = device.newCommandQueue()
    }
    
    func buildPipeline() {
        // Shader setup
        let library = device.newDefaultLibrary()!
        let vertexFunction = library.newFunctionWithName("renderVert")
        let fragmentFunction = library.newFunctionWithName("renderFrag")

        // Pipeline Descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = MapMesh.vertexDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .Depth32Float
        pipelineDescriptor.sampleCount = sampleCount
        
        // Try creating the pipeline
        pipeline = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    func buildResources() {
        uniforms = Uniforms(
            modelMatrix: GLKMatrix4Identity,
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: GLKMatrix4MakePerspective(fov, aspect, 0.01, 10000.0)
        )

        // Initialize Uniforms Buffer
        uniformBuffer = device.newBufferWithLength(
            sizeof(Uniforms),
            options: .OptionCPUCacheModeDefault
        )
    }
    
    func draw() {
        if let drawable = metalLayer.nextDrawable() {
            uniforms.viewMatrix = camera.getViewMatrix()

            // Copy uniforms to GPU
            memcpy(uniformBuffer.contents(), &uniforms, sizeof(Uniforms))
            
            // Create Command Buffer
            let commandBuffer = commandQueue.commandBuffer()
            
            // Depth buffer
            let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                .Depth32Float,
                width: Int(self.view.frame.width),
                height: Int(self.view.frame.height),
                mipmapped: false
            )
            depthTextureDescriptor.textureType = .Type2DMultisample
            depthTextureDescriptor.sampleCount = sampleCount
            let depthTexture = device.newTextureWithDescriptor(depthTextureDescriptor)
            
            // Depth stencil
            let stencilDescriptor = MTLDepthStencilDescriptor()
            stencilDescriptor.depthCompareFunction = .LessEqual
            stencilDescriptor.depthWriteEnabled = true
            let depthState = device.newDepthStencilStateWithDescriptor(stencilDescriptor)
            
            // MSAA
            let msaaDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                .BGRA8Unorm,
                width: Int(self.view.frame.width),
                height: Int(self.view.frame.height),
                mipmapped: false
            )
            
            msaaDescriptor.textureType = .Type2DMultisample
            msaaDescriptor.sampleCount = sampleCount
            let msaaTexture = device.newTextureWithDescriptor(msaaDescriptor)
            
            // Render Pass Descriptor
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = msaaTexture
            renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.8, 0.3, 0.2, 1)
            renderPassDescriptor.colorAttachments[0].loadAction = .Clear
            renderPassDescriptor.colorAttachments[0].storeAction = .MultisampleResolve
            
            
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .Clear
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
            
            // Command Encoder
            let commandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            commandEncoder.setDepthStencilState(depthState)
            commandEncoder.setRenderPipelineState(pipeline)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)

            mapMesh.renderWithEncoder(commandEncoder)

            commandEncoder.endEncoding()
            
            // Commit command buffer
            commandBuffer.presentDrawable(drawable)
            commandBuffer.commit()
        }
    }
    
    func redraw() {
        autoreleasepool {
            self.draw()
        }
    }
    
    func startDisplayTimer() {
        timer = CADisplayLink(target: self, selector: Selector("redraw"))
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    func handlePan(gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocityInView(self.view)
        let newPitch = GLKMathDegreesToRadians(Float(velocity.y / -100))
        let newYaw = GLKMathDegreesToRadians(Float(velocity.x / -100))
        
        camera.pitch(newPitch)
        camera.turn(newYaw)
    }

    func handlePinch(gesture: UIPinchGestureRecognizer) {
        let velocity = Float(gesture.velocity / 2)
        if velocity.isNaN || velocity < 0.1  { return }
        camera.moveForward(velocity)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.whiteColor()
        aspect = Float(self.view.bounds.size.width / self.view.bounds.size.height)

        initializeMetal()
        loadMap()
        buildPipeline()
        buildResources()
        startDisplayTimer()

        // Set up gesture recognizers
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "handlePan:"))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: "handlePinch:"))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    deinit {
        timer.invalidate()
    }
}

