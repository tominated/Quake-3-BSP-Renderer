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
    var time: Float32
    var modelMatrix : GLKMatrix4
    var viewMatrix : GLKMatrix4
    var projectionMatrix : GLKMatrix4
}

class ViewController: UIViewController {
    // Main metal objects
    let metalLayer = CAMetalLayer()
    let device = MTLCreateSystemDefaultDevice()!
    
    var commandQueue : MTLCommandQueue! = nil
    
    // Resources
    var uniformBufferProvider: BufferProvider! = nil
    var mapMesh : MapMesh! = nil
    var uniforms : Uniforms! = nil
    var depthTexture : MTLTexture! = nil
    var msaaTexture : MTLTexture! = nil
    
    let sampleCount = 2
    
    // Transients
    var timer : CADisplayLink! = nil
    var startTime : CFTimeInterval = 0.0
    var elapsedTime : Float32 = 0.0
    
    var aspect : Float = 0.0
    var fov : Float = GLKMathDegreesToRadians(65.0)
    var camera : Camera = Camera()
    
    func loadMap() {
        let pk3 = NSBundle.mainBundle().URLForResource("pak0", withExtension: "pk3")!
        let loader = Q3ResourceLoader(dataFilePath: pk3)
        
        let map = loader.loadMap("q3dm6")!
        
        let shaderParser = Q3ShaderParser(shaderFile: loader.loadAllShaders())
        let shaders = try! shaderParser.readShaders()
        
        let shaderBuilder = ShaderBuilder(device: device)
        let textureLoader = Q3TextureLoader(loader: loader, device: device)
        
        mapMesh = MapMesh(device: self.device, map: map, shaderBuilder: shaderBuilder, textureLoader: textureLoader, shaders: shaders)
    }
    
    func initializeMetal() {
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        
        view.layer.addSublayer(metalLayer)
        
        commandQueue = device.newCommandQueue()
    }
    
    func buildResources() {
        uniforms = Uniforms(
            time: 1,
            modelMatrix: GLKMatrix4Identity,
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: GLKMatrix4MakePerspective(fov, aspect, 0.01, 10000.0)
        )

        uniformBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            bufferSize: sizeof(Uniforms)
        )
        
        // Depth buffer
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            .Depth32Float,
            width: Int(self.view.frame.width),
            height: Int(self.view.frame.height),
            mipmapped: false
        )
        depthTextureDescriptor.textureType = .Type2D
        depthTexture = device.newTextureWithDescriptor(depthTextureDescriptor)
    }
    
    func draw() {
        if let drawable = metalLayer.nextDrawable() {
            uniforms.time = elapsedTime
            uniforms.viewMatrix = camera.getViewMatrix()

            let uniformBuffer = uniformBufferProvider.nextBuffer()
            
            // Copy uniforms to GPU
            memcpy(uniformBuffer.contents(), &uniforms, sizeof(Uniforms))
            
            // Create Command Buffer
            let commandBuffer = commandQueue.commandBuffer()
            
            // Render Pass Descriptor
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .Clear
            renderPassDescriptor.colorAttachments[0].storeAction = .DontCare
            
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .Clear
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
            
            // Command Encoder
            let commandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
            commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, atIndex: 0)

            mapMesh.renderWithEncoder(commandEncoder, time: Float(timer.timestamp))

            commandEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { (commandBuffer) -> Void in
                self.uniformBufferProvider.finishedWithBuffer()
            }
            
            // Commit command buffer
            commandBuffer.presentDrawable(drawable)
            commandBuffer.commit()
        }
    }
    
    
    
    func redraw(displayLink: CADisplayLink) {
        if startTime == 0.0 {
            startTime = displayLink.timestamp
        }
        
        elapsedTime = Float32(displayLink.timestamp - startTime);
        
        autoreleasepool {
            self.draw()
        }
    }
    
    func startDisplayTimer() {
        timer = CADisplayLink(target: self, selector: #selector(ViewController.redraw(_:)))
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
        buildResources()
        startDisplayTimer()

        // Set up gesture recognizers
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(ViewController.handlePan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(ViewController.handlePinch(_:))))
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

