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

struct Uniforms {
    let modelMatrix : GLKMatrix4
    let viewMatrix : GLKMatrix4
    let projectionMatrix : GLKMatrix4
}

class ViewController: UIViewController {
    // Main metal objects
    let metalLayer = CAMetalLayer()
    let device = MTLCreateSystemDefaultDevice()!
    
    var commandQueue : MTLCommandQueue! = nil
    var pipeline : MTLRenderPipelineState! = nil
    
    // Resources
    var uniformBuffer : MTLBuffer! = nil
    var vertexBuffer : MTLBuffer! = nil
    var indexBuffer : MTLBuffer! = nil
    
    // Game resources
    var bsp : BSPMap! = nil
    
    // Transients
    var timer : CADisplayLink! = nil
    var lastFrameTimestamp : CFTimeInterval = 0.0
    var elapsedTime : CFTimeInterval = 0.0
    
    var aspect : Float = 0.0
    var fov : Float = Float(65.0 * (M_PI / 180))
    
    let up : GLKVector3 = GLKVector3Make(0, 1, 0)
    var position : GLKVector3 = GLKVector3Make(-500, -1, -800)
    var direction : GLKVector3 = GLKVector3Normalize(GLKVector3Make(0, 0, 1))
    
    func loadMap() {
        let filename = NSBundle.mainBundle().pathForResource("test_bigbox", ofType: "bsp")!
        let binaryData = NSData(contentsOfFile: filename)!
        bsp = readMapData(binaryData)
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
        
        // Vertex Descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        var vertexOffset = 0
        
        // Vertex Position
        vertexDescriptor.attributes[0].offset = vertexOffset
        vertexDescriptor.attributes[0].format = .Float4
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexOffset += sizeof(GLKVector4)
        
        // Vertex Normal
        vertexDescriptor.attributes[1].offset = vertexOffset
        vertexDescriptor.attributes[1].format = .Float4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexOffset += sizeof(GLKVector4)
        
        // Vertex Color
        vertexDescriptor.attributes[2].offset = vertexOffset
        vertexDescriptor.attributes[2].format = .Float4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexOffset += sizeof(GLKVector4)
        
        // Vertex Texture Coordinate
        vertexDescriptor.attributes[3].offset = vertexOffset
        vertexDescriptor.attributes[3].format = .Float2
        vertexDescriptor.attributes[3].bufferIndex = 0
        vertexOffset += sizeof(GLKVector2)
        
        // Vertex Lightmap Coordinate
        vertexDescriptor.attributes[4].offset = vertexOffset
        vertexDescriptor.attributes[4].format = .Float2
        vertexDescriptor.attributes[4].bufferIndex = 0
        vertexOffset += sizeof(GLKVector2)
        
        // Vertex Descriptor stride
        vertexDescriptor.layouts[0].stride = sizeof(Vertex)
        
        // Pipeline Descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        // Try creating the pipeline
        pipeline = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    func buildResources() {
        // Initialize Vertex Buffer
        vertexBuffer = device.newBufferWithBytes(
            bsp.vertices,
            length: bsp.vertices.count * sizeof(Vertex),
            options: .OptionCPUCacheModeDefault
        )
        
        // Initialize Uniforms Buffer
        uniformBuffer = device.newBufferWithLength(
            sizeof(Uniforms),
            options: .OptionCPUCacheModeDefault
        )
        
        // Initialize Index Buffer
        indexBuffer = device.newBufferWithLength(
            bsp.meshVerts.count * sizeof(UInt32),
            options: .OptionCPUCacheModeDefault
        )
    }
    
    func draw() {
        if let drawable = metalLayer.nextDrawable() {
            // Build uniforms
            var uniforms = Uniforms(
                modelMatrix: GLKMatrix4Identity,
                viewMatrix: GLKMatrix4MakeLookAt(
                    position.x, position.y, position.z,
                    direction.x, direction.y, direction.z,
                    up.x, up.y, up.z
                ),
                projectionMatrix: GLKMatrix4MakePerspective(fov, aspect, 0.01, 1000.0)
            )
            
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
            commandEncoder.setRenderPipelineState(pipeline)
            commandEncoder.setCullMode(.None)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
            
            // Draw Call
//            commandEncoder.drawIndexedPrimitives(
//                .Triangle,
//                indexCount: 0,
//                indexType: .UInt32,
//                indexBuffer: indexBuffer,
//                indexBufferOffset: 0
//            )

            commandEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: bsp.vertices.count)

            
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

    func handlePan(gestureRecognizer: UIPanGestureRecognizer) {

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.whiteColor()
        aspect = Float(self.view.bounds.size.width / self.view.bounds.size.height)
        
        loadMap()
        initializeMetal()
        buildPipeline()
        buildResources()
        startDisplayTimer()

        // Set up gesture recognizers
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "handlePan:"))
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

