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
    private var startTime = CACurrentMediaTime()

    // Resources
    var uniformBufferProvider: BufferProvider! = nil
    var mapMesh: MapMesh! = nil
    var uniforms: Uniforms! = nil
    var camera: Camera! = nil

    // Testing new stuff:
    var bsp: Quake3BSP! = nil
    var visTester: VisibilityTester! = nil
    var newMapMesh: MTKMesh! = nil
    var materials: Dictionary<String, Material> = Dictionary()
    var lightmaps: Array<MTLTexture> = []
    var defaultTexture: MTLTexture! = nil

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

        let parsedMap = Q3Map(data: map)

        let shaderParser = Q3ShaderParser(shaderFile: loader.loadAllShaders())
        let allShaders = try! shaderParser.readShaders()

        let shaderBuilder = ShaderBuilder(device: device)
        let textureLoader = Q3TextureLoader(loader: loader, device: device)

        // TRYING OUT NEW STUFF

        // Parse the BSP file
        print("running new map parser")
        let mapParser = try BSPParser(bspData: map)
        bsp = try mapParser.parse()
        print("new map parser ran!")

        // Get the face visibility tester
        visTester = VisibilityTester(bsp: bsp)

        // Get the meshes
        print("building meshes")
        let allocator = MTKMeshBufferAllocator(device: device)
        let meshBuilder = BSPMeshBuilder(withAllocator: allocator, for: bsp)
        let mdlMesh = try meshBuilder.buildMapMesh()
        newMapMesh = try MTKMesh(mesh: mdlMesh, device: device)
        print("finished building meshes")

        // Build the 'Material's from the list of textures and build shaders
        let texturesInMap = Set(bsp.textures.map { $0.name })
        var shaders: Dictionary<String, Q3Shader> = [:]

        for shader in allShaders {
            if texturesInMap.contains(shader.name) {
                shaders[shader.name] = shader
            }
        }

        for texture in bsp.textures {
            let shader = shaders[texture.name] ?? Q3Shader(textureName: texture.name)
            materials[texture.name] = try Material(
                shader: shader,
                device: device,
                shaderBuilder: shaderBuilder,
                textureLoader: textureLoader
            )
        }

        // Build the lightmap textures
        defaultTexture = textureLoader.loadWhiteTexture()

        for lightmap in bsp.lightmaps {
            self.lightmaps.append(textureLoader.loadLightmap(lightmap.lightmap))
        }


        // END NEW STUFF

        mapMesh = MapMesh(
            device: device,
            map: parsedMap,
            shaderBuilder: shaderBuilder,
            textureLoader: textureLoader,
            shaders: allShaders
        )
    }

    func makeResources() {
        aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)

        uniforms = Uniforms(
            time: 0,
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
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = Float(size.width / size.height)
        uniforms.projectionMatrix = GLKMatrix4MakePerspective(FOV, aspectRatio, 0.01, 10000.0)
    }

    func draw(in view: MTKView) {
        // Figure out what faces are visibile
        let visibleIndices = visTester.getVisibleFaceIndices(at:
            float3(camera.position.x, camera.position.y, camera.position.z))
        let percentVisible: Float = (Float(visibleIndices.count) / Float(bsp.faces.count)) * 100
        print("percent visible: \(percentVisible)%")

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
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 0)

        mapMesh.renderWithEncoder(commandEncoder, time: uniforms.time)

        // End the gpu commands
        commandEncoder.endEncoding()

        // And finally display stuff
        commandBuffer.present(currentDrawable)
    }

    // This function will get all the currently visible faces, then group them
    // by their texture so the shaders/textures/etc don't have to be re-bound
    // for every face
    private func getRenderGroups() -> Array<Array<Int>> {
        let position = float3(camera.position.x, camera.position.y, camera.position.z)
        let visibleFaceIndices = visTester.getVisibleFaceIndices(at: position)
        let sortedFaceIndices = visibleFaceIndices.sorted(by: compareFaces)

        // We group the faces by their texture in order to set up the shader,
        // then draw all stages in minimal state changes
        var groupedFaces: Array<Array<Int>> = []
        var currentGroup: Array<Int> = []

        for faceIndex in sortedFaceIndices {
            let face = bsp.faces[faceIndex]

            // If currentGroup has entries, and last entry has different texture
            // we can add the currentGroup array to the groupedFaces array
            if let lastFaceIndex = currentGroup.last {
                if face.textureIndex != bsp.faces[lastFaceIndex].textureIndex {
                    groupedFaces.append(currentGroup)
                    currentGroup = []
                }
            }

            currentGroup.append(faceIndex)
        }

        // The last group needs to be added manually
        groupedFaces.append(currentGroup)

        return groupedFaces
    }

    // Sort faces by texture name, then lightmap index
    private func compareFaces(_ a: Int, _ b: Int) -> Bool {
        let faceA = self.bsp.faces[a]
        let faceB = self.bsp.faces[b]
        let textureA = self.bsp.textures[Int(faceA.textureIndex)]
        let textureB = self.bsp.textures[Int(faceB.textureIndex)]

        if textureA.name > textureB.name {
            return true
        }

        if textureB.name > textureA.name {
            return false
        }

        if faceA.lightmapIndex > faceB.lightmapIndex {
            return true
        }
        
        return false
    }
}
