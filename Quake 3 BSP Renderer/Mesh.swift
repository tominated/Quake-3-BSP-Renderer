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

protocol RenderableWithEncoder {
    func renderWithEncoder(encoder: MTLRenderCommandEncoder)
}

class FaceMesh: RenderableWithEncoder {
    let indexCount: Int
    let indexBuffer: MTLBuffer
    
    init(device: MTLDevice, indices: [UInt32]) {
        indexCount = indices.count
        indexBuffer = device.newBufferWithBytes(
            indices,
            length: indices.count * sizeof(UInt32),
            options: .CPUCacheModeDefaultCache
        )
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        encoder.drawIndexedPrimitives(
            .Triangle,
            indexCount: indexCount,
            indexType: .UInt32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
}

class PatchMesh: RenderableWithEncoder {
    let face: Face
    let vertexBuffer: MTLBuffer
    
    init(device: MTLDevice, face: Face) {
        // TODO: Implement bezier curves and tesselation
        self.face = face
        
        self.vertexBuffer = device.newBufferWithLength(1, options: .CPUCacheModeDefaultCache)
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        // TODO: Figure out a nice way to render another buffer without breaking
        // normal faces
    }
}

class MapMesh {
    let device: MTLDevice
    let bsp: BSPMap
    
    let vertexBuffer: MTLBuffer
    var faceMeshes: [FaceMesh] = []
    var patchMeshes: [PatchMesh] = []
    
    init(device: MTLDevice, bsp: BSPMap) {
        self.device = device
        self.bsp = bsp
        
        self.vertexBuffer = device.newBufferWithBytes(
            bsp.vertices,
            length: sizeof(Vertex) * bsp.vertices.count,
            options: .CPUCacheModeDefaultCache
        )
        
        createFaceMeshes()
    }
    
    private func createFaceMeshes() {
        let model = bsp.models[0]
        
        let faceIndices = model.face..<(model.face + model.faceCount)
        
        for index in faceIndices {
            let face = bsp.faces[index]
            
            // We only know how to render basic faces for now
            guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }
            
            // Vertex indices go through meshverts for polygons and meshes.
            // The resulting indices need to be UInt32 for metal index buffers.
            let indices = face.meshVertIndexes().map({ i in
                bsp.meshVerts[Int(i)].offset + UInt32(face.vertex)
            })
            
            faceMeshes.append(FaceMesh(device: self.device, indices: indices))
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        
        for faceMesh in faceMeshes {
            faceMesh.renderWithEncoder(encoder)
        }
        
        for patchMesh in patchMeshes {
            patchMesh.renderWithEncoder(encoder)
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
