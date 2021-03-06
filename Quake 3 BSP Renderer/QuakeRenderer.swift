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
    private var startTime = CACurrentMediaTime()

    // Resources
    var uniformBufferProvider: BufferProvider! = nil
    var mapMesh: MapMesh! = nil
    var uniforms: Uniforms! = nil
    var camera: Camera! = nil

    init(withMetalKitView view: MTKView, map mapName: String, camera: Camera) throws {
        super.init()

        self.mapName = mapName
        self.view = view
        self.camera = camera

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

        // get spawn points and set camera position to one
        let spawnPoints = map.entities.filter { entity in
            entity["classname"] == "info_player_deathmatch"
        }

        if (spawnPoints.count > 0) {
            let i = Int(arc4random_uniform(UInt32(spawnPoints.count)))
            let entity = spawnPoints[i]
            let angle = Float(entity["angle"]!)!
            let origin = entity["origin"]!.split(separator: " ").map { Float($0)! }

            camera.position = GLKVector3Make(origin[0], origin[2] + 5, -origin[1])
            camera.yaw = angle
        }

        let shaderParser = Q3ShaderParser(shaderFile: loader.loadAllShaders())
        let shaders = try! shaderParser.readShaders()

        let textureLoader = Q3TextureLoader(loader: loader, device: device)

        mapMesh = MapMesh(
            device: device,
            map: map,
            textureLoader: textureLoader,
            shaders: shaders
        )
    }

    func makeResources() {
        aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)

        uniforms = Uniforms(
            time: 0,
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
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
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

        // Update the time & view matrix in the uniforms
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniforms.viewMatrix = camera.getViewMatrix()

        // Fill the uniform buffer
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)

        // Get a command encoder so we can send gpu commands through
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        // Perform the main draw calls
        commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

        mapMesh.renderWithEncoder(commandEncoder!, time: uniforms.time)

        // End the gpu commands
        commandEncoder?.endEncoding()

        // And finally display stuff
        commandBuffer.present(currentDrawable)
    }

}
