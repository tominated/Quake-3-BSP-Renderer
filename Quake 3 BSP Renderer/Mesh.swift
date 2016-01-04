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

class MapMesh {
    struct FaceMesh {
        let offset: Int
        let count: Int
        let textureName: String
    }
    
    let device: MTLDevice
    let bsp: BSPMap
    
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    var faceMeshes: [FaceMesh] = []
    var indices: [UInt32] = []
    var textures: Dictionary<String, MTLTexture> = Dictionary()
    
    init(device: MTLDevice, bsp: BSPMap) {
        self.device = device
        self.bsp = bsp
        
        self.vertexBuffer = device.newBufferWithBytes(
            bsp.vertices,
            length: sizeof(Vertex) * bsp.vertices.count,
            options: .CPUCacheModeDefaultCache
        )
        
        createIndexBuffer()
        createTextures()
    }
    
    private func createIndexBuffer() {
        let model = bsp.models[0]
        let faceIndices = model.face..<(model.face + model.faceCount)
        
        for index in faceIndices {
            let face = bsp.faces[index]
            
            // We only know how to render basic faces for now
            guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }
            
            // Vertex indices go through meshverts for polygons and meshes.
            // The resulting indices need to be UInt32 for metal index buffers.
            let meshVertIndices = face.meshVertIndexes()
            
            let textureName = bsp.textures[face.texture].name
            
            faceMeshes.append(
                FaceMesh(
                    offset: indices.count,
                    count: meshVertIndices.count,
                    textureName: textureName
                )
            )
            
            for i in meshVertIndices {
                indices.append(
                    bsp.meshVerts[Int(i)].offset + UInt32(face.vertex)
                )
            }
        }
        
        indexBuffer = device.newBufferWithBytes(
            indices,
            length: indices.count * sizeof(UInt32),
            options: .CPUCacheModeDefaultCache
        )
    }
    
    func createTextures() {
        let textureLoader = MTKTextureLoader(device: device)
        
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
                continue
            }
            
            print("adding texture \(texture.name)")
            
            self.textures[texture.name] = try! textureLoader.newTextureWithContentsOfURL(
                url,
                options: [
                    MTKTextureLoaderOptionTextureUsage: MTLTextureUsage.ShaderRead.rawValue
                ]
            )
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        
        for faceMesh in faceMeshes {
            if let texture = textures[faceMesh.textureName] {
                encoder.setFragmentTexture(texture, atIndex: 0)
            }
            
            encoder.drawIndexedPrimitives(
                .Triangle,
                indexCount: faceMesh.count,
                indexType: .UInt32,
                indexBuffer: indexBuffer,
                indexBufferOffset: faceMesh.offset * sizeof(UInt32)
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
