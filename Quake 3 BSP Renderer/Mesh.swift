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
    struct BezierFace {
        let vertexBuffer: MTLBuffer
        let indexBuffer: MTLBuffer
        let size: Int
    }
    
    struct PatchFace {
        let bezierFaces: [BezierFace]
        let textureName: String
    }
    
    let device: MTLDevice
    let bsp: BSPMap
    
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    var indices: [UInt32] = []
    var groupedFaces = Dictionary<String, Array<UInt32>>()
    var groupedIndices = Dictionary<String, MTLBuffer>()
    var patchFaces: [PatchFace] = []
    var textures: Dictionary<String, MTLTexture> = Dictionary()
    var defaultTexture: MTLTexture! = nil
    
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
            
            let textureName = bsp.textures[face.texture].name
            
            if groupedFaces[textureName] == nil {
               groupedFaces[textureName] = []
            }
            
            if face.faceType == .Polygon || face.faceType == .Mesh {
                // Vertex indices go through meshverts for polygons and meshes.
                // The resulting indices need to be UInt32 for metal index buffers.
                for i in face.meshVertIndexes() {
                    groupedFaces[textureName]!.append(
                        bsp.meshVerts[Int(i)].offset + UInt32(face.vertex)
                    )
                }
            } else if face.faceType == .Patch {
                print("creating patch")
                patchFaces.append(createPatchFace(face))
            }
        }
        
        for (textureName, indices) in groupedFaces {
            groupedIndices[textureName] = device.newBufferWithBytes(
                indices,
                length: indices.count * sizeof(UInt32),
                options: .CPUCacheModeDefaultCache
            )
        }
    }
    
    func createPatchFace(face: Face) -> PatchFace {
        let numPatchesX = ((face.size.0) - 1) / 2
        let numPatchesY = ((face.size.1) - 1) / 2
        let numPatches = numPatchesX * numPatchesY
        
        var beziers: [BezierFace] = []
        
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
            beziers.append(
                BezierFace(
                    vertexBuffer: device.newBufferWithBytes(
                        bezier.vertices,
                        length: bezier.vertices.count * sizeof(Vertex),
                        options: .CPUCacheModeDefaultCache
                    ),
                    indexBuffer: device.newBufferWithBytes(
                        bezier.indices,
                        length: bezier.indices.count * sizeof(UInt32),
                        options: .CPUCacheModeDefaultCache
                    ),
                    size: bezier.indices.count
                )
            )
        }
        
        return PatchFace(
            bezierFaces: beziers,
            textureName: bsp.textures[face.texture].name
        )
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
        
        for (textureName, buffer) in groupedIndices {
            let arr = groupedFaces[textureName]!
            
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
        
        // Render patches
        for patchFace in patchFaces {
            encoder.setFragmentTexture(
                textures[patchFace.textureName] ?? defaultTexture,
                atIndex: 0
            )
            
            for bezierFace in patchFace.bezierFaces {
                encoder.setVertexBuffer(
                    bezierFace.vertexBuffer,
                    offset: 0,
                    atIndex: 0
                )
                
                encoder.drawIndexedPrimitives(
                    .Triangle,
                    indexCount: bezierFace.size,
                    indexType: .UInt32,
                    indexBuffer: bezierFace.indexBuffer,
                    indexBufferOffset: 0
                )
            }
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
