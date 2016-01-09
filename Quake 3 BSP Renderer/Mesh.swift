//
//  Mesh.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/11/2015.
//  Copyright © 2015 Thomas Brunoli. All rights reserved.
//

import GLKit
import ModelIO
import MetalKit

struct PolygonFaceMesh {
    let indices: [UInt32]
    let texture: String
    
    init(face: Face, bsp: BSPMap) {
        texture = bsp.textures[face.texture].name
        
        // Vertex indices go through meshverts for polygons and meshes.
        // The resulting indices need to be UInt32 for metal index buffers.
        indices = face.meshVertIndexes().map { i in
            bsp.meshVerts[Int(i)].offset + UInt32(face.vertex)
        }
    }
}

struct PatchFaceMesh {
    var vertices: [Vertex] = []
    var indices: [UInt32] = []
    let texture: String
    
    init(face: Face, bsp: BSPMap) {
        texture = bsp.textures[face.texture].name
        
        // Calculate patch stuff
        let numPatchesX = ((face.size.0) - 1) / 2
        let numPatchesY = ((face.size.1) - 1) / 2
        let numPatches = numPatchesX * numPatchesY
        
        for patchNumber in 0..<numPatches {
            let xStep = patchNumber % numPatchesX
            let yStep = patchNumber / numPatchesX
            
            var vertexGrid: [[Vertex]] = Array(
                count: Int(face.size.0),
                repeatedValue: Array(
                    count: Int(face.size.1),
                    repeatedValue: Vertex.empty()
                )
            )
            
            var gridX = 0
            var gridY = 0
            for index in face.vertex..<(face.vertex + face.vertexCount) {
                vertexGrid[gridX][gridY] = bsp.vertices[index]
                
                gridX += 1
                
                if gridX == Int(face.size.0) {
                    gridX = 0
                    gridY += 1
                }
            }
            
            let vi = 2 * xStep
            let vj = 2 * yStep
            var controlVertices: [Vertex] = []
            
            for i in 0..<3 {
                for j in 0..<3 {
                    controlVertices.append(vertexGrid[Int(vi + j)][Int(vj + i)])
                }
            }
            
            let bezier = Bezier(controls: controlVertices)
            self.indices.appendContentsOf(
                bezier.indices.map { i in i + UInt32(self.vertices.count) }
            )
            self.vertices.appendContentsOf(bezier.vertices)
        }
    }
}

class MapMesh {
    let device: MTLDevice
    let bsp: BSPMap
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    var groupedIndices: Dictionary<String, [UInt32]> = Dictionary()
    var groupedIndexBuffers: Dictionary<String, MTLBuffer> = Dictionary()
    var textures: Dictionary<String, MTLTexture> = Dictionary()
    var defaultTexture: MTLTexture! = nil
    
    init(device: MTLDevice, bsp: BSPMap) {
        self.device = device
        self.bsp = bsp
        
        var vertices = bsp.vertices
        
        // Get the faces for the main map model
        let model = bsp.models[0]
        let faceIndices = model.face..<(model.face + model.faceCount)
        
        for index in faceIndices {
            let face = bsp.faces[index]
            let textureName = bsp.textures[face.texture].name
            
            // Ensure we have an array to append to
            if groupedIndices[textureName] == nil {
                groupedIndices[textureName] = []
            }
            
            if face.faceType == .Polygon || face.faceType == .Mesh {
                let mesh = PolygonFaceMesh(face: face, bsp: self.bsp)
                groupedIndices[textureName]?.appendContentsOf(mesh.indices)
            } else if face.faceType == .Patch {
                let mesh = PatchFaceMesh(face: face, bsp: bsp)
                groupedIndices[textureName]?.appendContentsOf(
                    mesh.indices.map { i in i + UInt32(vertices.count) }
                )
                vertices.appendContentsOf(mesh.vertices)
            }
        }
        
        vertexBuffer = device.newBufferWithBytes(
            vertices,
            length: vertices.count * sizeof(Vertex),
            options: .CPUCacheModeDefaultCache
        )
        
        for (textureName, indices) in groupedIndices {
            groupedIndexBuffers[textureName] = device.newBufferWithBytes(
                indices,
                length: indices.count * sizeof(UInt32),
                options: .CPUCacheModeDefaultCache
            )
        }
        
        createTextures()
    }
    
    func createTextures() {
        let textureLoader = MTKTextureLoader(device: device)
        let textureOptions = [
            MTKTextureLoaderOptionTextureUsage: MTLTextureUsage.ShaderRead.rawValue,
            MTKTextureLoaderOptionAllocateMipmaps: 1
        ]
        
        // Create default texture
        let checkerboard = MDLCheckerboardTexture(
            divisions: 32,
            name: "defaultTexture",
            dimensions: vector2(128, 128),
            channelCount: 4,
            channelEncoding: .UInt8,
            color1: UIColor.blackColor().CGColor,
            color2: UIColor.whiteColor().CGColor
        )
        
        let tmpDir = NSURL.fileURLWithPath(NSTemporaryDirectory(), isDirectory: true)
        let checkerboardPath = tmpDir.URLByAppendingPathComponent("checkerboard").URLByAppendingPathExtension("png")
        
        checkerboard.writeToURL(checkerboardPath)
        
        defaultTexture = try! textureLoader.newTextureWithContentsOfURL(
            checkerboardPath,
            options: textureOptions
        )
        
        
        for texture in bsp.textures {
            // Check if texture exists (as a jpg, then as a png)
            guard let url = NSBundle.mainBundle().URLForResource(
                texture.name,
                withExtension: "jpg",
                subdirectory: "xcsv_bq3hi-res"
                ) ?? NSBundle.mainBundle().URLForResource(
                    texture.name,
                    withExtension: "png",
                    subdirectory: "xcsv_bq3hi-res"
                ) else {
                    print("couldn't load texture \(texture.name)")
                    continue
            }
            
            print("loading texture \(texture.name)")
            
            self.textures[texture.name] = try! textureLoader.newTextureWithContentsOfURL(
                url,
                options: textureOptions
            )
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        
        for (textureName, buffer) in groupedIndexBuffers {
            let arr = groupedIndices[textureName]!
            
            let texture = textures[textureName] ?? defaultTexture
            encoder.setFragmentTexture(texture, atIndex: 0)
            
            encoder.drawIndexedPrimitives(
                .Triangle,
                indexCount: arr.count,
                indexType: .UInt32,
                indexBuffer: buffer,
                indexBufferOffset: 0
            )
        }
    }
    
    static func vertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        var offset = 0
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(GLKVector4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(GLKVector4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(GLKVector4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float2
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(GLKVector2)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float2
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(GLKVector2)
        
        descriptor.layouts[0].stepFunction = .PerVertex
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }
}