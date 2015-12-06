//
//  Mesh.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/11/2015.
//  Copyright © 2015 Thomas Brunoli. All rights reserved.
//

import GLKit
import ModelIO

private func vertexDescriptor() -> MDLVertexDescriptor {
    let vertexDescriptor = MDLVertexDescriptor()
    var offset = 0

    vertexDescriptor.addOrReplaceAttribute(
        MDLVertexAttribute(
            name: "position",
            format: .Float4,
            offset: offset,
            bufferIndex: 0
        )
    )

    offset += sizeof(GLKVector4)

    vertexDescriptor.addOrReplaceAttribute(
        MDLVertexAttribute(
            name: "normal",
            format: .Float4,
            offset: offset,
            bufferIndex: 0
        )
    )

    offset += sizeof(GLKVector4)

    vertexDescriptor.addOrReplaceAttribute(
        MDLVertexAttribute(
            name: "color",
            format: .Float4,
            offset: offset,
            bufferIndex: 0
        )
    )

    offset += sizeof(GLKVector4)

    vertexDescriptor.addOrReplaceAttribute(
        MDLVertexAttribute(
            name: "textureCoordinate",
            format: .Float2,
            offset: offset,
            bufferIndex: 0
        )
    )

    offset += sizeof(GLKVector2)

    vertexDescriptor.addOrReplaceAttribute(
        MDLVertexAttribute(
            name: "lightmapCoordinate",
            format: .Float2,
            offset: offset,
            bufferIndex: 0
        )
    )

    vertexDescriptor.setPackedOffsets()
    vertexDescriptor.setPackedStrides()

    return vertexDescriptor
}

private func faceSubmeshes(
    bsp: BSPMap,
    allocator: MDLMeshBufferAllocator
) -> [MDLSubmesh] {
    var submeshes : [MDLSubmesh] = []
    let model = bsp.models[0]

    let faceIndices = model.face..<(model.face + model.faceCount)

    for index in faceIndices {
        let face = bsp.faces[index]

        guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }

        let indices = face.meshVertIndexes().map({ i in
            bsp.meshVerts[Int(i)].offset + UInt32(face.vertex)
        })

        let bytes = NSData(bytes: indices, length: indices.count * sizeof(UInt32))
        let buffer = allocator.newBufferWithData(bytes, type: .Index)

        submeshes.append(
            MDLSubmesh(
                indexBuffer: buffer,
                indexCount: face.meshVertCount,
                indexType: .UInt32,
                geometryType: .TypeTriangles,
                material: nil
            )
        )
    }

    return submeshes
}

func createMesh(
    bsp: BSPMap,
    allocator: MDLMeshBufferAllocator
) -> MDLMesh {
    let bytes = NSData(bytes: bsp.vertices, length: bsp.vertices.count * sizeof(Vertex))
    let vertexBuffer = allocator.newBufferWithData(bytes, type: .Vertex)
    
    return MDLMesh(
        vertexBuffer: vertexBuffer,
        vertexCount: bsp.vertices.count,
        descriptor: vertexDescriptor(),
        submeshes: faceSubmeshes(bsp, allocator: allocator)
    )
}
