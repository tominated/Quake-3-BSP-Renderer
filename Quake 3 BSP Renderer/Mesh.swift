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

func vertexDescriptor() -> MDLVertexDescriptor {
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

class MapMesh {
    let bsp: BSPMap
    let device: MTLDevice
    let allocator: MDLMeshBufferAllocator

    var faceToSubmesh: Dictionary<Int, Int> = Dictionary()
    var submeshes: [MDLSubmesh] = []
    var mesh: MTKMesh! = nil

    init(bsp: BSPMap, device: MTLDevice) {
        self.bsp = bsp
        self.device = device
        self.allocator = MTKMeshBufferAllocator(device: device)

        createSubmeshes()
        createMesh()
    }

    func renderWithEncoder(encoder: MTLRenderCommandEncoder) {
        let vertexBuffer = mesh.vertexBuffers[0]

        encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, atIndex: 0)

        for submesh in mesh.submeshes {
            encoder.drawIndexedPrimitives(
                submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }
    }

    func renderVisibleFaces(position: GLKVector3, encoder: MTLRenderCommandEncoder) {
        let faceIndexes = bsp.visibleFaceIndices(position)
        let vertexBuffer = mesh.vertexBuffers[0]

        // Don't believe XCode's lies - this prevents an implicit coersion from
        // an NSArray to Swift Array for every face
        let submeshes = mesh.submeshes as! [MTKSubmesh]

        encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, atIndex: 0)

        for faceIndex in faceIndexes {
            guard let submeshIndex = faceToSubmesh[faceIndex] else { continue }

            let submesh = submeshes[submeshIndex]

            encoder.drawIndexedPrimitives(
                submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }
    }

    private func createSubmeshes() {
        let model = bsp.models[0]

        let faceIndices = model.face..<(model.face + model.faceCount)

        for index in faceIndices {
            let face = bsp.faces[index]

            guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }

            faceToSubmesh[index] = submeshes.count

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
    }

    private func createMesh() {
        let bytes = NSData(bytes: bsp.vertices, length: bsp.vertices.count * sizeof(Vertex))
        let vertexBuffer = allocator.newBufferWithData(bytes, type: .Vertex)

        let mdlMesh = MDLMesh(
            vertexBuffer: vertexBuffer,
            vertexCount: bsp.vertices.count,
            descriptor: vertexDescriptor(),
            submeshes: self.submeshes
        )

        mesh = try! MTKMesh(mesh: mdlMesh, device: self.device)
    }
}
