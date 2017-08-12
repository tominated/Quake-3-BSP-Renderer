//
//  Q3Map.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import GLKit

private struct Q3DirectoryEntry {
    var offset: Int32
    var length: Int32
}

private struct Q3PolygonFace {
    let indices: Array<UInt32>
    
    init(meshverts: [UInt32], firstVertex: Int, firstMeshvert: Int, meshvertCount: Int) {
        let meshvertIndices = firstMeshvert..<(firstMeshvert + meshvertCount)
        indices = meshvertIndices.map { meshverts[$0] + UInt32(firstVertex) }
    }
}

private struct Q3PatchFace {
    var vertices: Array<Q3Vertex> = []
    fileprivate var indices: Array<UInt32> = []
    
    init(vertices: Array<Q3Vertex>, firstVertex: Int, vertexCount: Int, size: (Int, Int)) {
        let numPatchesX = ((size.0) - 1) / 2
        let numPatchesY = ((size.1) - 1) / 2
        let numPatches = numPatchesX * numPatchesY
        
        for patchNumber in 0..<numPatches {
            // Find the x & y of this patch in the grid
            let xStep = patchNumber % numPatchesX
            let yStep = patchNumber / numPatchesX
            
            // Initialise the vertex grid
            var vertexGrid: [[Q3Vertex]] = Array(
                repeating: Array(
                    repeating: Q3Vertex(),
                    count: Int(size.1)
                ),
                count: Int(size.0)
            )
            
            var gridX = 0
            var gridY = 0
            for index in firstVertex..<(firstVertex + vertexCount) {
                // Place the vertices from the face in the vertex grid
                vertexGrid[gridX][gridY] = vertices[index]
                
                gridX += 1
                
                if gridX == Int(size.0) {
                    gridX = 0
                    gridY += 1
                }
            }
            
            let vi = 2 * xStep
            let vj = 2 * yStep
            var controlVertices: [Q3Vertex] = []
            
            for i in 0..<3 {
                for j in 0..<3 {
                    controlVertices.append(vertexGrid[Int(vi + j)][Int(vj + i)])
                }
            }
            
            let bezier = Bezier(controls: controlVertices)
            self.indices.append(
                contentsOf: bezier.indices.map { i in i + UInt32(self.vertices.count) }
            )
            self.vertices.append(contentsOf: bezier.vertices)
        }
    }
    
    func offsetIndices(_ offset: UInt32) -> Array<UInt32> {
        return self.indices.map { $0 + offset }
    }
}


// Encapsulates the reading of graphics data from a Quake 3 BSP.
// Reads vertices, faces, texture and lightmap data from the map and turns them
// in to a format to easily consume in a modern graphics API.
// Performs tessellation on bezier patch faces and integrates them with all of
// the other face vertices and index arrays
class Q3Map {
    var vertices: Array<Q3Vertex> = []
    var faces: Array<Q3Face> = []
    var textureNames: Array<String> = []
    var lightmaps: Array<Q3Lightmap> = []
    
    fileprivate var buffer: BinaryReader
    fileprivate var directoryEntries: Array<Q3DirectoryEntry> = []
    fileprivate var meshverts: Array<UInt32> = []
    
    // Read the map data from an NSData buffer containing the bsp file
    init(data: Data) {
        buffer = BinaryReader(data: data)
        
        readHeaders()
        textureNames = readTextureNames()
        vertices = readVertices()
        meshverts = readMeshverts()
        lightmaps = readLightmaps()
        faces = readFaces()
    }
    
    fileprivate func readHeaders() {
        // Magic should always equal IBSP for Q3 maps
        let magic = buffer.getASCII(4)!
        assert(magic == "IBSP", "Magic must be equal to \"IBSP\"")
        
        // Version should always equal 0x2e for Q3 maps
        let version = buffer.getInt32()
        assert(version == 0x2e, "Version must be equal to 0x2e")
        
        // Directory entries define the position and length of a section
        for _ in 0..<17 {
            let entry = Q3DirectoryEntry(offset: buffer.getInt32(), length: buffer.getInt32())
            directoryEntries.append(entry)
        }
    }
    
    fileprivate func readTextureNames() -> Array<String> {
        return readEntry(1, length: 72) { buffer in
            return buffer.getASCIIUntilNull(64)
        }
    }
    
    fileprivate func readVertices() -> Array<Q3Vertex> {
        return readEntry(10, length: 44) { buffer in
            let position = self.swizzle(float4(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32(), 1.0))
            let textureCoord = float2(buffer.getFloat32(), 1 - buffer.getFloat32())
            let lightmapCoord = float2(buffer.getFloat32(), buffer.getFloat32())
            let normal = self.swizzle(float4(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32(), 1.0))
            let r = Float(buffer.getUInt8()) / 255
            let g = Float(buffer.getUInt8()) / 255
            let b = Float(buffer.getUInt8()) / 255
            let a = Float(buffer.getUInt8()) / 255
            let color = float4(r, g, b, a)
            
            return Q3Vertex(
                position: position,
                normal: normal,
                color: color,
                textureCoord: textureCoord,
                lightmapCoord: lightmapCoord
            )
        }
    }
    
    fileprivate func readMeshverts() -> Array<UInt32> {
        return readEntry(11, length: 4) { buffer in
            return UInt32(buffer.getInt32())
        }
    }
    
    
    fileprivate func readLightmaps() -> Array<Q3Lightmap> {
        return readEntry(14, length: 128 * 128 * 3) { buffer in
            var lm: Q3Lightmap = []
            
            for _ in 0..<(128 * 128) {
                lm.append((buffer.getUInt8(), buffer.getUInt8(), buffer.getUInt8(), 255))
            }
            
            return lm
        }
    }
    
    fileprivate func readFaces() -> Array<Q3Face> {
        return readEntry(13, length: 104) { buffer in
            let textureIndex = Int(buffer.getInt32())
            buffer.skip(4) // effect
            let type = Q3FaceType(rawValue: Int(buffer.getInt32()))!
            let firstVertex = Int(buffer.getInt32())
            let vertexCount = Int(buffer.getInt32())
            let firstMeshvert = Int(buffer.getInt32())
            let meshvertCount = Int(buffer.getInt32())
            let lightmapIndex = Int(buffer.getInt32())
            buffer.skip(64) // Extranious lightmap info
            let patchSizeX = Int(buffer.getInt32())
            let patchSizeY = Int(buffer.getInt32())
            
            let textureName = self.textureNames[textureIndex]
            
            if type == .polygon || type == .mesh {
                let polygonFace = Q3PolygonFace(
                    meshverts: self.meshverts,
                    firstVertex: firstVertex,
                    firstMeshvert: firstMeshvert,
                    meshvertCount: meshvertCount
                )
                
                return Q3Face(
                    textureName: textureName,
                    lightmapIndex: lightmapIndex,
                    vertexIndices: polygonFace.indices
                )
            } else if type == .patch {
                let patchFace = Q3PatchFace(
                    vertices: self.vertices,
                    firstVertex: firstVertex,
                    vertexCount: vertexCount,
                    size: (patchSizeX, patchSizeY)
                )
                
                // The indices for a patch will be for it's own vertices.
                // Offset them by the amount of vertices in the map, then add
                // the patch's own vertices to the list
                let indices = patchFace.offsetIndices(UInt32(self.vertices.count))
                self.vertices.append(contentsOf: patchFace.vertices)
                
                return Q3Face(
                    textureName: textureName,
                    lightmapIndex: lightmapIndex,
                    vertexIndices: indices
                )
            }
            
            return nil
        }
    }
    
    fileprivate func readEntry<T>(_ index: Int, length: Int, each: (BinaryReader) -> T?) -> Array<T> {
        let entry = directoryEntries[index]
        let itemCount = Int(entry.length) / length
        var accumulator: Array<T> = []
        
        for i in 0..<itemCount {
            buffer.jump(Int(entry.offset) + (i * length))
            if let value = each(buffer) { accumulator.append(value) }
        }
        
        return accumulator
    }
    
    fileprivate func swizzle(_ v: float3) -> float3 {
        return float3(v.x, v.z, -v.y)
    }
    
    fileprivate func swizzle(_ v: float4) -> float4 {
        return float4(v.x, v.z, -v.y, 1)
    }
}
