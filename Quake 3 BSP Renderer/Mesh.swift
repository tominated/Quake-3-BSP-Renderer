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

class MapMesh {
    let device: MTLDevice
    let map: Q3Map
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    var groupedIndices: Dictionary<IndexGroupKey, [UInt32]> = Dictionary()
    var groupedIndexBuffers: Dictionary<IndexGroupKey, MTLBuffer> = Dictionary()
    var textures: Dictionary<String, MTLTexture> = Dictionary()
    var lightmaps: [MTLTexture] = []
    var defaultTexture: MTLTexture! = nil
    
    init(device: MTLDevice, map: Q3Map, textures: Dictionary<String, UIImage>) {
        self.device = device
        self.map = map
        
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
            groupedIndexBuffers[key] = device.newBufferWithBytes(
                indices,
                length: indices.count * sizeof(UInt32),
                options: .CPUCacheModeDefaultCache
            )
        }
        
        createTextures(textures)
        createLightmaps()
    }
    
    private func createTextures(textures: Dictionary<String, UIImage>) {
        let textureLoader = MTKTextureLoader(device: device)
        let textureOptions = [
            MTKTextureLoaderOptionTextureUsage: MTLTextureUsage.ShaderRead.rawValue,
            MTKTextureLoaderOptionAllocateMipmaps: 1
        ]
        
        // Create white texture
        let defaultDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            .RGBA8Unorm,
            width: 128,
            height: 128,
            mipmapped: false
        )
        defaultTexture = device.newTextureWithDescriptor(defaultDescriptor)
        defaultTexture.replaceRegion(
            MTLRegionMake2D(0, 0, 128, 128),
            mipmapLevel: 0,
            withBytes: Array(
                count: 128 * 128 * 4,
                repeatedValue: UInt8(255)
            ),
            bytesPerRow: 128 * 4
        )
        
        for (textureName, texture) in textures {
            print("loading texture '\(textureName)'")
            
            do {
                self.textures[textureName] = try textureLoader.newTextureWithCGImage(texture.CGImage!, options: textureOptions)
            } catch {
                print("  Error loading \(textureName)")
            }
        }
    }
    
    private func createLightmaps() {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            .RGBA8Unorm,
            width: 128,
            height: 128,
            mipmapped: true
        )
        
        for lm in map.lightmaps {
            let texture = device.newTextureWithDescriptor(textureDescriptor)

            texture.replaceRegion(
                MTLRegionMake2D(0, 0, 128, 128),
                mipmapLevel: 0,
                withBytes: lm,
                bytesPerRow: 128 * 4
            )
            
            self.lightmaps.append(texture)
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        
        for (key, buffer) in groupedIndexBuffers {
            let arr = groupedIndices[key]!
            
            let texture = textures[key.texture] ?? defaultTexture
            let lightmap = key.lightmap > -1 ? lightmaps[key.lightmap] : defaultTexture
            
            encoder.setFragmentTexture(texture, atIndex: 0)
            encoder.setFragmentTexture(lightmap, atIndex: 1)
            
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
        offset += sizeof(float4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(float4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float4
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(float4)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float2
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(float2)
        
        descriptor.attributes[0].offset = offset
        descriptor.attributes[0].format = .Float2
        descriptor.attributes[0].bufferIndex = 0
        offset += sizeof(float2)
        
        descriptor.layouts[0].stepFunction = .PerVertex
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }
}