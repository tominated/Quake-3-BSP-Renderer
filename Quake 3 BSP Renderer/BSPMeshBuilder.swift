//
//  BSPMeshBuilder.swift
//  BSPMeshBuilder
//
//  Created by Thomas Brunoli on {TODAY}.
//  Copyright © 2017 Thomas Brunoli. All rights reserved.
//

import Foundation
import ModelIO

public class BSPMeshBuilder {
    public enum MeshBuilderError: Error {
        case invalidModel
    }

    let allocator: MDLMeshBufferAllocator
    let bsp: Quake3BSP

    // This is so billboards can actually be placed as a submesh to preserve the
    // face order without breaking the allocator (can't allocate 0)
    let billboardVertices = (0 ..< 3).map { _ in
        BSPVertex(
            position: float3(0, 0, 0),
            surfaceTextureCoord: float2(0, 0),
            lightmapTextureCoord: float2(0, 0),
            normal: float3(0, 0, 0),
            color: float4(0, 0, 0, 0)
        )
    }

    public init(withAllocator allocator: MDLMeshBufferAllocator, for bsp: Quake3BSP) {
        self.allocator = allocator
        self.bsp = bsp
    }

    public func buildMapMesh() throws -> MDLMesh {
        guard let model = bsp.models.first else {
            throw MeshBuilderError.invalidModel
        }

        var vertices: Array<BSPVertex> = bsp.vertices
        var subMeshes: Array<MDLSubmesh> = []

        for faceIndex in model.faceIndices {
            let face = bsp.faces[Int(faceIndex)]

            switch face.type {
            case .polygon, .mesh:
                subMeshes.append(buildPolygonFaceSubmesh(face: face))

            case .billboard:
                // Because buffers need to actually contain something, and we
                // want to preserve the face order, use some dummy data for
                // billboards as they have no vertices.
                let indices: Array<UInt32> = (0 ..< 3).map { UInt32($0 + vertices.count) }
                vertices.append(contentsOf: billboardVertices)
                let indicesData = indices.withUnsafeBufferPointer { return Data(buffer: $0) }
                let indexBuffer = allocator.newBuffer(with: indicesData, type: .index)
                subMeshes.append(
                    MDLSubmesh(
                        indexBuffer: indexBuffer,
                        indexCount: indices.count,
                        indexType: .uint32,
                        geometryType: .triangles,
                        material: nil
                    )
                )

            case .patch:
                // Tesselate vertices
                let faceVertices = face.vertexIndices.map { vertices[Int($0)] }
                let bezierPatch = BezierPatch(faceVertices: faceVertices, size: face.size)
                let (bezierVertices, bezierIndices) = bezierPatch.buildFace()

                // Offset the indices by the current amount of vertices
                let indices = bezierIndices.map { $0 + UInt32(vertices.count) }

                // Add the bezier vertices to the vertices
                vertices.append(contentsOf: bezierVertices)

                // Generate the submesh
                let indicesData = indices.withUnsafeBufferPointer { return Data(buffer: $0) }
                let indexBuffer = allocator.newBuffer(with: indicesData, type: .index)

                subMeshes.append(
                    MDLSubmesh(
                        indexBuffer: indexBuffer,
                        indexCount: indices.count,
                        indexType: .uint32,
                        geometryType: .triangles,
                        material: nil
                    )
                )

            }

        }

        let vertexData = vertices.withUnsafeBufferPointer { return Data(buffer: $0) }
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        return MDLMesh(
            vertexBuffer: vertexBuffer,
            vertexCount: vertices.count,
            descriptor: vertexDescriptor(),
            submeshes: subMeshes
        )
    }

    private func buildPolygonFaceSubmesh(face: BSPFace) -> MDLSubmesh {
        var indices: Array<UInt32> = []

        for meshVertIndex in face.meshVertIndices {
            let meshVert = bsp.meshVerts[Int(meshVertIndex)]
            let vertexIndex = face.vertexIndices.lowerBound + meshVert.vertexIndexOffset
            indices.append(UInt32(vertexIndex))
        }

        let indicesData = indices.withUnsafeBufferPointer { return Data(buffer: $0) }
        let indexBuffer = allocator.newBuffer(with: indicesData, type: .index)

        return MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            indexType: .uint32,
            geometryType: .triangles,
            material: nil
        )
    }

    private func vertexDescriptor() -> MDLVertexDescriptor {
        let descriptor = MDLVertexDescriptor()

        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: 12,
            bufferIndex: 0
        )

        descriptor.attributes[2] = MDLVertexAttribute(
            name: "lightmapCoordinate",
            format: .float2,
            offset: 20,
            bufferIndex: 0
        )

        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: 28,
            bufferIndex: 0
        )

        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeColor,
            format: .float4,
            offset: 40,
            bufferIndex: 0
        )

        return descriptor
    }
}
