//
//  Mesh.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/11/2015.
//  Copyright © 2015 Thomas Brunoli. All rights reserved.
//

import simd
import ModelIO
import MetalKit

struct IndexGroupKey: Hashable {
    let texture: String
    let lightmap: Int
    
    var hashValue: Int {
        return texture.hashValue ^ lightmap.hashValue
    }
}

func ==(lhs: IndexGroupKey, rhs: IndexGroupKey) -> Bool {
    return lhs.texture == rhs.texture && lhs.lightmap == rhs.lightmap
}

struct FaceMesh {
    let sort: Int32
    let material: Material
    let lightmap: MTLTexture
    let indexCount: Int
    let indexBuffer: MTLBuffer
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder, time: Float) {
        material.renderWithEncoder(encoder, time: time, indexBuffer: indexBuffer, indexCount: indexCount, lightmap: lightmap)
    }
}

class MapMesh {
    let device: MTLDevice
    let map: Q3Map
    let textureLoader: Q3TextureLoader
    var vertexBuffer: MTLBuffer! = nil
    var shaders: Dictionary<String, Q3Shader> = Dictionary()
    var faceMeshes: Array<FaceMesh> = []
    var shadedFaceMeshes: Array<FaceMesh> = []
    
    init(device: MTLDevice, map: Q3Map, shaderBuilder: ShaderBuilder, textureLoader: Q3TextureLoader, shaders: Array<Q3Shader>) {
        self.device = device
        self.map = map
        self.textureLoader = textureLoader
        
        let defaultTexture = textureLoader.loadWhiteTexture()
        
        let texturesInMap = Set(map.textureNames)
        
        for shader in shaders {
            if texturesInMap.contains(shader.name) {
                self.shaders[shader.name] = shader
            }
        }
        
        var groupedIndices: Dictionary<IndexGroupKey, [UInt32]> = Dictionary()
        
        for face in map.faces {
            if (face.textureName == "noshader") { continue }
            
            let key = IndexGroupKey(
                texture: face.textureName,
                lightmap: face.lightmapIndex
            )
            
            // Ensure we have an array to append to
            if groupedIndices[key] == nil {
                groupedIndices[key] = []
            }
            
            groupedIndices[key]?.appendContentsOf(face.vertexIndices)
        }
        
        vertexBuffer = device.newBufferWithBytes(
            map.vertices,
            length: map.vertices.count * sizeof(Q3Vertex),
            options: .CPUCacheModeDefaultCache
        )
        
        for (key, indices) in groupedIndices {
            var shaded = false

            if self.shaders[key.texture] != nil {
                shaded = true
            }
            
            let shader = self.shaders[key.texture] ?? Q3Shader(textureName: key.texture)
            let material = try! Material(shader: shader, device: device, shaderBuilder: shaderBuilder, textureLoader: textureLoader)
            
            let lightmap = key.lightmap >= 0
                ? textureLoader.loadLightmap(map.lightmaps[key.lightmap])
                : defaultTexture
            
            let buffer = device.newBufferWithBytes(
                indices,
                length: indices.count * sizeof(UInt32),
                options: .CPUCacheModeDefaultCache
            )
            
            let faceMesh = FaceMesh(
                sort: shader.sort.order(),
                material: material,
                lightmap: lightmap,
                indexCount: indices.count,
                indexBuffer: buffer
            )
            
            if shaded {
                shadedFaceMeshes.append(faceMesh)
            } else {
                faceMeshes.append(faceMesh)
            }
        }
        
        faceMeshes.sortInPlace { a, b in a.sort < b.sort }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder, time: Float) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        
        for faceMesh in faceMeshes {
            faceMesh.renderWithEncoder(encoder, time: time)
        }
        
        for faceMesh in shadedFaceMeshes {
            faceMesh.renderWithEncoder(encoder, time: time)
        }
    }
    
    static func vertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        var offset = 0
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(float4)
        
        descriptor.attributes[1].offset = offset
        descriptor.attributes[1].format = .Float4
        descriptor.attributes[1].bufferIndex = 0
        offset += sizeof(float4)
        
        descriptor.attributes[2].offset = offset
        descriptor.attributes[2].format = .Float4
        descriptor.attributes[2].bufferIndex = 0
        offset += sizeof(float4)
        
        descriptor.attributes[3].offset = offset
        descriptor.attributes[3].format = .Float2
        descriptor.attributes[3].bufferIndex = 0
        offset += sizeof(float2)
        
        descriptor.attributes[4].offset = offset
        descriptor.attributes[4].format = .Float2
        descriptor.attributes[4].bufferIndex = 0
        offset += sizeof(float2)
        
        descriptor.layouts[0].stepFunction = .PerVertex
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }
}