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
    var bsp : BSPMap! = nil
    var mesh : MTKMesh! = nil
    var uniforms : Uniforms! = nil
    
    // Transients
    var timer : CADisplayLink! = nil
    var lastFrameTimestamp : CFTimeInterval = 0.0
    var elapsedTime : CFTimeInterval = 0.0
    
    var aspect : Float = 0.0
    var fov : Float = Float(65.0 * (M_PI / 180))

    // In degrees
    var yaw : Float = 90.0
    var pitch : Float = 90.0

    var up : GLKVector3 = GLKVector3Make(0, 1, 0)
    var position : GLKVector3 = GLKVector3Make(0, 0, 400)
    var direction : GLKVector3 = GLKVector3Make(0, 0, 1)
    
    func loadMap() {
        let filename = NSBundle.mainBundle().pathForResource("test_bigbox", ofType: "bsp")!
        let binaryData = NSData(contentsOfFile: filename)!
        bsp = readMapData(binaryData)

        let allocator = MTKMeshBufferAllocator(device: self.device)
        mesh = try! MTKMesh(
            mesh: createMesh(bsp, allocator: allocator),
            device: self.device
        )
    }

    func lookat() -> GLKMatrix4 {
        let yawR = GLKMathDegreesToRadians(yaw)
        let pitchR = GLKMathDegreesToRadians(pitch)

        let centreX = cos(yawR) * cos(pitchR)
        let centreY = sin(yawR) * cos(pitchR)
        let centreZ = sin(pitchR)

        return GLKMatrix4MakeLookAt(
            position.x, position.y, position.z,
            centreX + position.x, centreY + position.y, centreZ + position.z,
            0, 1, 0
        )
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
        
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        // Try creating the pipeline
        pipeline = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    func buildResources() {
        uniforms = Uniforms(
            modelMatrix: GLKMatrix4Identity,
            viewMatrix: lookat(),
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
            uniforms.viewMatrix = lookat()

            // Copy uniforms to GPU
            memcpy(uniformBuffer.contents(), &uniforms, sizeof(Uniforms))
            
            // Create Command Buffer
            let commandBuffer = commandQueue.commandBuffer()
            
            // Render Pass Descriptor
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.8, 0.3, 0.2, 1)
            renderPassDescriptor.colorAttachments[0].loadAction = .Clear
            
            // Command Encoder
            let commandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            let vertexBuffer = mesh.vertexBuffers[0]
            commandEncoder.setRenderPipelineState(pipeline)
            commandEncoder.setCullMode(.Front)
            commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, atIndex: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)

            for submesh in mesh.submeshes {
                commandEncoder.drawIndexedPrimitives(
                    submesh.primitiveType,
                    indexCount: submesh.indexCount,
                    indexType: submesh.indexType,
                    indexBuffer: submesh.indexBuffer.buffer,
                    indexBufferOffset: submesh.indexBuffer.offset
                )
            }

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
        let newPitch = (Float(velocity.x / -100) + yaw) % 360
        let newYaw = (Float(velocity.y / -100) + pitch) % 360

        print("yaw: \(newYaw), pitch: \(newPitch)")
        yaw = newYaw
        pitch = newPitch
    }

    func handlePinch(gesture: UIPinchGestureRecognizer) {
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

