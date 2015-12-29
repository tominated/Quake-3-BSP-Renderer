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

class Plane {
    // Plane Normal
    var normal: GLKVector3
    
    // Distance from origin to plane normal
    var dist: Float
    
    init(normal: GLKVector3, dist: Float) {
        self.normal = normal
        self.dist = dist
    }
}

class Node {
    // Plane index
    var plane: Int
    
    // Indices of children. Negative numbers are leaf indices: -(leaf + 1)
    var children: (Int, Int)
    
    // Bounding box min
    var mins: Vec3I
    
    // Bounding box max
    var maxs: Vec3I
    
    init(plane: Int, children: (Int, Int), mins: Vec3I, maxs: Vec3I) {
        self.plane = plane
        self.children = children
        self.mins = mins
        self.maxs = maxs
    }
}

class Leaf {
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
    
    init(cluster: Int, area: Int, mins: Vec3I, maxs: Vec3I, leafFace: Int, leafFaceCount: Int) {
        self.cluster = cluster
        self.area = area
        self.mins = mins
        self.maxs = maxs
        self.leafFace = leafFace
        self.leafFaceCount = leafFaceCount
    }
}

class LeafFace {
    // Face index
    var face: Int
    
    init(face: Int) {
        self.face = face
    }
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

func +(left: Vertex, right: Vertex) -> Vertex {
    let position = GLKVector4Add(left.position, right.position)
    let normal = GLKVector4Add(left.normal, right.normal)

    // TODO: Calculate correct color, texture & lightmap coords
    return Vertex(
        position: position,
        normal: normal,
        color: left.color,
        textureCoord: left.textureCoord,
        lightMapCoord: left.lightMapCoord
    )
}

func *(left: Vertex, right: Float) -> Vertex {
    let position = GLKVector4MultiplyScalar(left.position, right)
    let normal = GLKVector4MultiplyScalar(left.normal, right)
    
    // TODO: Calculate correct color, texture & lightmap coords
    return Vertex(
        position: position,
        normal: normal,
        color: left.color,
        textureCoord: left.textureCoord,
        lightMapCoord: left.lightMapCoord
    )
}

struct MeshVert {
    // Vertex index offset, relative to first vertex of corresponding face
    var offset: UInt32
}

enum FaceType: Int {
    case Polygon = 1, Patch = 2, Mesh = 3, Billboard = 4
}

class Face {
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
    var lightMapOrigin: GLKVector3
    
    // World space lightmap s and t unit vectors
    var lightmapVectors: (GLKVector3, GLKVector3)
    
    // Surface normal
    var normal: GLKVector3
    
    // Patch dimensions
    var size: (Int32, Int32)
    
    init(
        faceType: FaceType,
        vertex: Int,
        vertexCount: Int,
        meshVert: Int,
        meshVertCount: Int,
        lightMap: Int,
        lightMapStart: (Int32, Int32),
        lightMapSize: (Int32, Int32),
        lightMapOrigin: GLKVector3,
        lightmapVectors: (GLKVector3, GLKVector3),
        normal: GLKVector3,
        size: (Int32, Int32)
    ) {
        self.faceType = faceType
        self.vertex = vertex
        self.vertexCount = vertexCount
        self.meshVert = meshVert
        self.meshVertCount = meshVertCount
        self.lightMap = lightMap
        self.lightMapStart = lightMapStart
        self.lightMapSize = lightMapSize
        self.lightMapOrigin = lightMapOrigin
        self.lightmapVectors = lightmapVectors
        self.normal = normal
        self.size = size
    }
    
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

class BSPMap {
    var buffer: BinaryReader! = nil
    var dirEntries: [DirEntry] = []
    var entities: String = ""
    var planes: [Plane] = []
    var nodes: [Node] = []
    var leaves: [Leaf] = []
    var leafFaces: [LeafFace] = []
    var models: [Model] = []
    var vertices: [Vertex] = []
    var meshVerts: [MeshVert] = []
    var faces: [Face] = []
    var lightMaps: [LightMap] = []
    var visdata: VisData! = nil
    
    init(data: NSData) {
        buffer = BinaryReader(data: data)
        
        // Magic should always equal IBSP for Q3 maps
        let magic = buffer.getASCII(4)!
        assert(magic == "IBSP", "Magic must be equal to \"IBSP\"")
        
        // Version should always equal 0x2e for Q3 maps
        let version = buffer.getInt32()
        assert(version == 0x2e, "Version must be equal to 0x2e")
        
        // Directory entries define the position and length of a section
        for _ in 0..<17 {
            let entry = DirEntry(offset: buffer.getInt32(), length: buffer.getInt32())
            dirEntries.append(entry)
        }
        
        readEntities()
        readPlanes()
        readNodes()
        readLeaves()
        readLeafFaces()
        readModels()
        readVertices()
        readMeshverts()
        readFaces()
        readLightmaps()
        readVisdata()
    }
    
    func visibleFaceIndices(position: GLKVector3) -> [Int] {
        let currentLeaf = leaves[findLeafIndex(position)]
        var alreadyVisible : Set<Int> = Set()
        var faceIndices : [Int] = []
        
        for leaf in leaves {
            guard isClusterVisible(currentLeaf.cluster, testCluster: leaf.cluster) else { continue }
            
            var i: Int
            for i = 0; i < leaf.leafFaceCount; i += 1 {
                // Get the index of the face from the leafFace
                let index = leafFaces[i + leaf.leafFace].face
                let face = faces[index]
                
                // Don't know how to render anything else yet
                guard face.faceType == .Polygon || face.faceType == .Mesh else { continue }
                
                // Add to the list if not already in it
                if !alreadyVisible.contains(index) {
                    faceIndices.append(index)
                    alreadyVisible.insert(index)
                }
            }
        }
        
        return faceIndices
    }
    
    private func isClusterVisible(currentCluster: Int, testCluster: Int) -> Bool {
        if visdata.vectorCount == 0 || currentCluster < 0 {
            return true
        }
        
        // This is some pretty weird code - I just converted it from C
        let i = (currentCluster * visdata.vectorSize) + (testCluster >> 3)
        let visSet = Int(visdata.vectors[i])
        
        return (visSet & (1 << (testCluster & 7))) != 0
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
    
    private func readEntities() {
        let entitiesEntry = dirEntries[0]
        buffer.jump(Int(entitiesEntry.offset))
        entities = buffer.getASCII(Int(entitiesEntry.length)) as! String
    }
    
    private func readPlanes() {
        let planeEntry = dirEntries[2]
        let numPlanes = Int(planeEntry.length) / 16
        
        // Read in the planes
        buffer.jump(Int(planeEntry.offset))
        
        for _ in 0..<numPlanes {
            let plane = Plane(
                normal: swizzle(GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())),
                dist: buffer.getFloat32()
            )
            planes.append(plane)
        }
    }
    
    private func readNodes() {
        let nodeEntry = dirEntries[3]
        let numNodes = Int(nodeEntry.length) / 36
        
        // Read in the nodes
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
    }
    
    private func readLeaves() {
        let leavesEntry = dirEntries[4]
        let numLeaves = Int(leavesEntry.length) / 48
        
        // Read the leaves
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
    }
    
    private func readLeafFaces() {
        let leafFacesEntry = dirEntries[5]
        let numLeafFaces = Int(leafFacesEntry.length) / 4
        
        // Read in the leaf faces
        buffer.jump(Int(leafFacesEntry.offset))
        
        for _ in 0..<numLeafFaces {
            leafFaces.append(LeafFace(face: Int(buffer.getInt32())))
        }
    }
    
    private func readModels() {
        let modelEntry = dirEntries[7]
        
        buffer.jump(Int(modelEntry.offset))
        
        let model = Model(
            mins: (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32()),
            maxs: (buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32()),
            face: Int(buffer.getInt32()),
            faceCount: Int(buffer.getInt32())
        )
        
        models = [model]
    }
    
    private func readVertices() {
        let verticesEntry = dirEntries[10]
        let numVertices = Int(verticesEntry.length) / 44
        
        // Read in the vertices
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
    }
    
    private func readMeshverts() {
        let meshVertEntry = dirEntries[11]
        let numMeshVerts = Int(meshVertEntry.length) / 4
        
        // Read in the mesh verts
        buffer.jump(Int(meshVertEntry.offset))
        
        for _ in 0..<numMeshVerts {
            meshVerts.append(MeshVert(offset: UInt32(buffer.getInt32())))
        }
    }
    
    private func readFaces() {
        let faceEntry = dirEntries[13]
        let numFaces = Int(faceEntry.length) / 104
        
        // Read in faces
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
            let lightMapOrigin = GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
            let lightMapVectorS = GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
            let lightMapVectorT = GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
            let normal = GLKVector3Make(buffer.getFloat32(), buffer.getFloat32(), buffer.getFloat32())
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
    }
    
    private func readLightmaps() {
        let lightMapEntry = dirEntries[14]
        let numLightMaps = Int(lightMapEntry.length) / (128 * 128 * 3)
        
        // Load in light maps
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
    }
    
    private func readVisdata() {
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
        
        visdata = VisData(
            vectorCount: vectorCount,
            vectorSize: vectorSize,
            vectors: vectors
        )
    }
}