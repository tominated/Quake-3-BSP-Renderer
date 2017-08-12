//
//  QuakeRenderer.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 12/8/17.
//  Copyright © 2017 Thomas Brunoli. All rights reserved.
//

import Foundation
import MetalKit
import GLKit

let FOV = GLKMathDegreesToRadians(65.0)

struct Uniforms {
    var time: Float32
    var modelMatrix : GLKMatrix4
    var viewMatrix : GLKMatrix4
    var projectionMatrix : GLKMatrix4
}

enum RendererError: Error {
    case deviceError
    case invalidMap
}

class QuakeRenderer: NSObject, MTKViewDelegate {
    private var mapName: String! = nil
    private var view: MTKView! = nil

    private var device: MTLDevice! = nil
    private var commandQueue: MTLCommandQueue! = nil

    private var aspectRatio: Float = 0.0

    // Resources
    var uniformBufferProvider: BufferProvider! = nil
    var mapMesh: MapMesh! = nil
    var uniforms: Uniforms! = nil
    var camera = Camera()

    init(withMetalKitView view: MTKView, andMap mapName: String) throws {
        super.init()

        self.mapName = mapName
        self.view = view

        self.device = view.device
        self.commandQueue = device.makeCommandQueue()

        try makeMapMesh()
        makeResources()
        configureView()
    }

    func makeMapMesh() throws {
        guard let device = self.device
            else { throw RendererError.deviceError }

        // Initialize the map stuff
        let pk3 = Bundle.main.url(forResource: "pak0", withExtension: "pk3")!
        let loader = Q3ResourceLoader(dataFilePath: pk3)

        guard
            let mapName = self.mapName,
            let map = loader.loadMap(mapName)
        else { throw RendererError.invalidMap }

        let shaderParser = Q3ShaderParser(shaderFile: loader.loadAllShaders())
        let shaders = try! shaderParser.readShaders()

        let shaderBuilder = ShaderBuilder(device: device)
        let textureLoader = Q3TextureLoader(loader: loader, device: device)

        mapMesh = MapMesh(
            device: device,
            map: map,
            shaderBuilder: shaderBuilder,
            textureLoader: textureLoader,
            shaders: shaders
        )
    }

    func makeResources() {
        aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)

        uniforms = Uniforms(
            time: 1,
            modelMatrix: GLKMatrix4Identity,
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: GLKMatrix4MakePerspective(FOV, aspectRatio, 0.01, 10000.0)
        )

        uniformBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            bufferSize: MemoryLayout<Uniforms>.size
        )
    }

    func configureView() {
        view.clearColor = MTLClearColorMake(1.0, 0, 0, 1.0) // Red
        view.clearDepth = 1.0
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.preferredFramesPerSecond = 60

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(QuakeRenderer.handlePan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(QuakeRenderer.handlePinch(_:))))
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = Float(size.width / size.height)
        uniforms.projectionMatrix = GLKMatrix4MakePerspective(FOV, aspectRatio, 0.01, 10000.0)
    }

    func draw(in view: MTKView) {
        // Get a command buffer if possible
        guard let commandBuffer = commandQueue?.makeCommandBuffer()
            else { return }

        // Ensure we commit the command buffer
        defer { commandBuffer.commit() }

        // Get a renderPassDescriptor and drawable if one is ready
        guard
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let currentDrawable = view.currentDrawable
            else { return }


        // Get a uniform buffer to write to, and ensure we signal when we're
        // finished with it
        let uniformBuffer = uniformBufferProvider.nextBuffer()
        commandBuffer.addCompletedHandler { _ in
            self.uniformBufferProvider.finishedWithBuffer()
        }

        // Fill the uniform buffer
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)

        // Get a command encoder so we can send gpu commands through
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        // Perform the main draw calls
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 0)

        mapMesh.renderWithEncoder(commandEncoder, time: uniforms.time)

        // End the gpu commands
        commandEncoder.endEncoding()

        // And finally display stuff
        commandBuffer.present(currentDrawable)
    }


    func handlePan(_ gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: self.view)
        let newPitch = GLKMathDegreesToRadians(Float(velocity.y / -100))
        let newYaw = GLKMathDegreesToRadians(Float(velocity.x / -100))

        camera.pitch(newPitch)
        camera.turn(newYaw)
        uniforms.viewMatrix = camera.getViewMatrix()
    }

    func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let velocity = Float(gesture.velocity / 2)
        if velocity.isNaN || velocity < 0.1  { return }
        camera.moveForward(velocity)
        uniforms.viewMatrix = camera.getViewMatrix()
    }

}
