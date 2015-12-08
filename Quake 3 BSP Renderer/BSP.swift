//
//  BSP.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import Foundation
import GLKit
import ModelIO

struct ColorRGBA {
    var r: Float32
    var g: Float32
    var b: Float32
    var a: Float32
    
    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = Float32(r) / 255
        self.g = Float32(g) / 255
        self.b = Float32(b) / 255
        self.a = Float32(a) / 255
    }
}

func colorToVec(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> GLKVector4 {
    return GLKVector4Make(Float32(r) / 255, Float32(g) / 255, Float32(b) / 255, Float32(a) / 255)
}

func swizzle(v: GLKVector3) -> GLKVector3 {
    return GLKVector3Make(v.x, v.z, -v.y)
}

func swizzle(v: GLKVector4) -> GLKVector4 {
    return GLKVector4Make(v.x, v.z, -v.y, 1)
}

struct TexCoords {
    var u: Float32
    var v: Float32
}

typealias Vec3F = (Float32, Float32, Float32)
typealias Vec3I = (Int32, Int32, Int32)

struct DirEntry {
    var offset: Int32
    var length: Int32
}

struct Header {
    var magic: String
    var version: Int
    var dirEntries: [DirEntry]
}

struct Plane {
    // Plane Normal
    var normal: GLKVector3
    
    // Distance from origin to plane normal
    var dist: Float
}

struct Node {
    // Plane index
    var plane: Int
    
    // Indices of children. Negative numbers are leaf indices: -(leaf + 1)
    var children: (Int, Int)
    
    // Bounding box min
    var mins: Vec3I
    
    // Bounding box max
    var maxs: Vec3I
}

struct Leaf {
    // Visdata cluster index
    var cluster: Int
    
    // Areaportal area
    var area: Int
    
    // Bounding box min
    var mins: Vec3I
    
    // Bounding box max
    var maxs: Vec3I
    
    // First leafFace
    var leafFace: Int
    
    // Number of leafFaces
    var leafFaceCount: Int
}

struct LeafFace {
    // Face index
    var face: Int
}

struct Model {
    // Bounding box min
    var mins: Vec3F
    
    // Bounding box max
    var maxs: Vec3F
    
    // First face
    var face: Int
    
    // Number of faces
    var faceCount: Int
}

struct Vertex {
    // Vertex Position
    var position: GLKVector4
    
    // Vertex normal
    var normal: GLKVector4
    
    // Vertex Colour
    var color: GLKVector4
    
    // Vertex texture coordinates
    var textureCoord: GLKVector2
    
    // Vertex lightmap coordinates.
    var lightMapCoord: GLKVector2
}

struct MeshVert {
    // Vertex index offset, relative to first vertex of corresponding face
    var offset: UInt32
}

enum FaceType: Int {
    case Polygon = 1, Patch = 2, Mesh = 3, Billboard = 4
}

struct Face {
    // The type of face
    var faceType: FaceType
    
    // First vertex
    var vertex: Int
    
    // Number of vertices
    var vertexCount: Int
    
    // First meshvert
    var meshVert: Int
    
    // Number of meshverts
    var meshVertCount: Int
    
    // Index of lightmap
    var lightMap: Int
    
    // Corner of this face's lightmap image in lightmap
    var lightMapStart: (Int32, Int32)
    
    // Size of this face's lightmap image in lightmap
    var lightMapSize: (Int32, Int32)
    
    // World space origin of lightmap
    var lightMapOrigin: Vec3F
    
    // World space lightmap s and t unit vectors
    var lightmapVectors: (Vec3F, Vec3F)
    
    // Surface normal
    var normal: Vec3F
    
    // Patch dimensions
    var size: (Int32, Int32)
    
    func meshVertIndexes() -> [Int] {
        // Only return indexes for polygons or meshes
        guard faceType == .Polygon || faceType == .Mesh else {
            return []
        }

        return Array(meshVert..<(meshVert + meshVertCount))
    }
}

struct LightMap {
    var map: [[(UInt8, UInt8, UInt8)]]
}

struct VisData {
    var vectorCount: Int
    var vectorSize: Int
    var vectors: [UInt8]
}

struct BSPMap {
    var entities: String
    var planes: [Plane]
    var nodes: [Node]
    var leaves: [Leaf]
    var leafFaces: [LeafFace]
    var models: [Model]
    var vertices: [Vertex]
    var meshVerts: [MeshVert]
    var faces: [Face]
    var lightMaps: [LightMap]
    var visdata: VisData
    
    private func isClusterVisible(currentCluster: Int, testCluster: Int) -> Bool {
        if visdata.vectorCount == 0 || currentCluster < 0 {
            return true
        }
        
        // This is some pretty weird code - I just converted it from C
        let i = (currentCluster * visdata.vectorSize) + (testCluster >> 3)
        let visSet = visdata.vectors[i]
        
        return (Int(visSet) & (1 << (testCluster & 7))) != 0
    }
    
    private func findLeafIndex(position: GLKVector3) -> Int {
        var index = 0
        
        while index >= 0 {
            let node = nodes[index]
            let plane = planes[node.plane]
            let distance = GLKVector3DotProduct(plane.normal, position) - plane.dist
            let (front, back) = node.children
            
            if distance >= 0 {
                index = front
            } else {
                index = back
            }
        }
        
        return -index - 1
    }
    
    func visibleFaceIndices(position: GLKVector3) -> [Int] {
        let currentLeaf = leaves[findLeafIndex(position)]
        var alreadyVisible : Set<Int> = Set()
        var faceIndices : [Int] = []
        
        for leaf in leaves {
            if isClusterVisible(currentLeaf.cluster, testCluster: leaf.cluster) {
                for leafFace in leaf.leafFace..<(leaf.leafFace + leaf.leafFaceCount) {
                    let index = leafFaces[leafFace].face
                    let face = faces[index]
                    guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }
                    
                    if !alreadyVisible.contains(index) {
                        faceIndices.append(index)
                        alreadyVisible.insert(index)
                    }
                }
            }
        }
        
        return faceIndices
    }
}

func readMapData(data: NSData) -> BSPMap {
    let buffer = BinaryReader(data: data)
    
    // Magic should always equal IBSP for Q3 maps
    let magic = buffer.getASCII(4)!
    assert(magic == "IBSP", "Magic must be equal to \"IBSP\"")
    
    // Version should always equal 0x2e for Q3 maps
    let version = buffer.getInt32()
    assert(version == 0x2e, "Version must be equal to 0x2e")
    
    // Directory entries define the position and length of a section
    var dirEntries = [DirEntry]()
    
    // Read all directory entries
    for _ in 0..<17 {
        let entry = DirEntry(offset: buffer.getInt32(), length: buffer.getInt32())
        dirEntries.append(entry)
    }

    // Read the entity descriptions
    let entitiesEntry = dirEntries[0]
    buffer.jump(Int(entitiesEntry.offset))
    let entities = buffer.getASCII(Int(entitiesEntry.length))
    
    // Find out how many planes there is
    let planeEntry = dirEntries[2]
    let numPlanes = Int(planeEntry.length) / 16
    
    // Read in the planes
    var planes = [Plane]()
    
    buffer.jump(Int(planeEntry.offset))
    
    for _ in 0..<numPlanes {
        let plane = Plane(
            normal: swizzle(GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())),
            dist: buffer.getFloat32()
        )
        planes.append(plane)
    }
    
    // Find out how many nodes there are
    let nodeEntry = dirEntries[3]
    let numNodes = Int(nodeEntry.length) / 36
    
    // Read in the nodes
    var nodes = [Node]()
    
    buffer.jump(Int(nodeEntry.offset))
    
    for _ in 0..<numNodes {
        let node = Node(
            plane: Int(buffer.getInt32()),
            children: (Int(buffer.getInt32()), Int(buffer.getInt32())),
            mins: (buffer.getInt32(), buffer.getInt32(), buffer.getInt32()),
            maxs: (buffer.getInt32(), buffer.getInt32(), buffer.getInt32())
        )
        nodes.append(node)
    }
    
    // Find out how many leaves there are
    let leavesEntry = dirEntries[4]
    let numLeaves = Int(leavesEntry.length) / 48
    
    // Read the leaves
    var leaves = [Leaf]()
    
    buffer.jump(Int(leavesEntry.offset))
    
    // NOTE: This output seems fishy...
    for _ in 0..<numLeaves {
        let leaf = Leaf(
            cluster: Int(buffer.getInt32()),
            area: Int(buffer.getInt32()),
            mins: (buffer.getInt32(), buffer.getInt32(), buffer.getInt32()),
            maxs: (buffer.getInt32(), buffer.getInt32(), buffer.getInt32()),
            leafFace: Int(buffer.getInt32()),
            leafFaceCount: Int(buffer.getInt32())
        )
        
        // Skip the brush information
        buffer.getInt32()
        buffer.getInt32()
        
        leaves.append(leaf)
    }
    
    // Find out how many leaf faces there are
    let leafFacesEntry = dirEntries[5]
    let numLeafFaces = Int(leafFacesEntry.length) / 4
    
    // Read in the leaf faces
    var leafFaces = [LeafFace]()
    
    buffer.jump(Int(leafFacesEntry.offset))
    
    for _ in 0..<numLeafFaces {
        leafFaces.append(LeafFace(face: Int(buffer.getInt32())))
    }
    
    // Get the model we care about (the map)
    let modelEntry = dirEntries[7]
    
    buffer.jump(Int(modelEntry.offset))
    
    let model = Model(
        mins: (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32()),
        maxs: (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32()),
        face: Int(buffer.getInt32()),
        faceCount: Int(buffer.getInt32())
    )
    
    let models = [model]
    
    // Find out how many vertices there are
    let verticesEntry = dirEntries[10]
    let numVertices = Int(verticesEntry.length) / 44
    
    // Read in the vertices
    var vertices = [Vertex]()
    
    buffer.jump(Int(verticesEntry.offset))
    
    for _ in 0..<numVertices {
        let position = swizzle(GLKVector4Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32(), 1.0))
        let textureCoord = GLKVector2Make(buffer.getFloat32(),buffer.getFloat32())
        let lightMapCoord = GLKVector2Make(buffer.getFloat32(),buffer.getFloat32())
        let normal = swizzle(GLKVector4Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32(), 1.0))
        let color = colorToVec(buffer.getUInt8(), g: buffer.getUInt8(), b: buffer.getUInt8(), a: buffer.getUInt8())
        
        let vertex = Vertex(
            position: position,
            normal: normal,
            color: color,
            textureCoord: textureCoord,
            lightMapCoord: lightMapCoord
        )
        
        vertices.append(vertex)
    }
    
    // Find out how many meshverts there are
    let meshVertEntry = dirEntries[11]
    let numMeshVerts = Int(meshVertEntry.length) / 4
    
    // Read in the mesh verts
    var meshVerts = [MeshVert]()
    
    buffer.jump(Int(meshVertEntry.offset))
    
    for _ in 0..<numMeshVerts {
        meshVerts.append(MeshVert(offset: UInt32(buffer.getInt32())))
    }
    
    // Find out how many faces there are
    let faceEntry = dirEntries[13]
    let numFaces = Int(faceEntry.length) / 104
    
    // Read in faces
    var faces = [Face]()
    
    buffer.jump(Int(faceEntry.offset))
    
    for _ in 0..<numFaces {
        let _ = buffer.getInt32() // texture
        let _ = buffer.getInt32() // effect
        let type = FaceType(rawValue: Int(buffer.getInt32()))!
        let vertex = Int(buffer.getInt32())
        let vertexCount = Int(buffer.getInt32())
        let meshVert = Int(buffer.getInt32())
        let meshVertCount = Int(buffer.getInt32())
        let lightMap = Int(buffer.getInt32())
        let lightMapStart = (buffer.getInt32(), buffer.getInt32())
        let lightMapSize = (buffer.getInt32(), buffer.getInt32())
        let lightMapOrigin = (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
        let lightMapVectorS = (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
        let lightMapVectorT = (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
        let normal = (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
        let size = (buffer.getInt32(), buffer.getInt32())
        
        let face = Face(
            faceType: type,
            vertex: vertex,
            vertexCount: vertexCount,
            meshVert: meshVert,
            meshVertCount: meshVertCount,
            lightMap: lightMap,
            lightMapStart: lightMapStart,
            lightMapSize: lightMapSize,
            lightMapOrigin: lightMapOrigin,
            lightmapVectors: (lightMapVectorS, lightMapVectorT),
            normal: normal,
            size: size
        )
        
        faces.append(face)
    }
    
    // Find out how many light maps there are
    let lightMapEntry = dirEntries[14]
    let numLightMaps = Int(lightMapEntry.length) / (128 * 128 * 3)
    
    // Load in light maps
    var lightMaps = [LightMap]()
    
    buffer.jump(Int(lightMapEntry.offset))
    
    for _ in 0..<numLightMaps {
        var map = [[(UInt8, UInt8, UInt8)]]()
        
        for _ in 0..<128 {
            var vals = [(UInt8, UInt8, UInt8)]()
            
            for _ in 0..<128 {
                vals.append((buffer.getUInt8(), buffer.getUInt8(), buffer.getUInt8()))
            }
            
            map.append(vals)
        }
        
        lightMaps.append(LightMap(map: map))
    }
    
    // Load the visdata in
    let visDataEntry = dirEntries[16]
    buffer.jump(Int(visDataEntry.offset))
    
    let vectorCount = Int(buffer.getInt32())
    let vectorSize = Int(buffer.getInt32())
    var vectors = [UInt8]()
    
    let xs = vectorCount * vectorSize
    
    if xs > 0 {
        for _ in 0..<xs {
            vectors.append(buffer.getUInt8())
        }
    }
    
    let visData = VisData(
        vectorCount: vectorCount,
        vectorSize: vectorSize,
        vectors: vectors
    )
    
    return BSPMap(
        entities: String(entities),
        planes: planes,
        nodes: nodes,
        leaves: leaves,
        leafFaces: leafFaces,
        models: models,
        vertices: vertices,
        meshVerts: meshVerts,
        faces: faces,
        lightMaps: lightMaps,
        visdata: visData
    )
}
