//
//  BSPTypes.swift
//  Quake3BSPParser
//
//  Created by Thomas Brunoli on 28/05/2017.
//  Copyright © 2017 Quake3BSPParser. All rights reserved.
//

import Foundation
import simd

public struct Quake3BSP {
    public var entities: BSPEntities?;
    public var textures: Array<BSPTexture> = [];
    public var planes: Array<BSPPlane> = [];
    public var nodes: Array<BSPNode> = [];
    public var leaves: Array<BSPLeaf> = [];
    public var leafFaces: Array<BSPLeafFace> = [];
    public var leafBrushes: Array<BSPLeafBrush> = [];
    public var models: Array<BSPModel> = [];
    public var brushes: Array<BSPBrush> = [];
    public var brushSides: Array<BSPBrushSide> = [];
    public var vertices: Array<BSPVertex> = [];
    public var meshVerts: Array<BSPMeshVert> = [];
    public var effects: Array<BSPEffect> = [];
    public var faces: Array<BSPFace> = [];
    public var lightmaps: Array<BSPLightmap> = [];
    public var lightVols: Array<BSPLightVol> = [];
    public var visdata: BSPVisdata?;

    init() {}
}

public struct BSPEntities {
    public let entities: String;
}

public struct BSPTexture {
    public let name: String;
    public let surfaceFlags: Int32;
    public let contentFlags: Int32;
}

public struct BSPPlane {
    public let normal: float3;
    public let distance: Float32;
}

public struct BSPNode {
    public enum NodeChild {
        case node(Int);
        case leaf(Int);
    }

    public let planeIndex: Int32;
    public let leftChild: NodeChild;
    public let rightChild: NodeChild;
    public let boundingBoxMin: int3;
    public let boundingBoxMax: int3;
}

public struct BSPLeaf {
    public let cluster: Int32;
    public let area: Int32;
    public let boundingBoxMin: int3;
    public let boundingBoxMax: int3;
    public let leafFaceIndices: CountableRange<Int32>;
    public let leafBrushIndices: CountableRange<Int32>;
}

public struct BSPLeafFace {
    public let faceIndex: Int32;
}

public struct BSPLeafBrush {
    public let brushIndex: Int32;
}

public struct BSPModel {
    public let boundingBoxMin: float3;
    public let boundingBoxMax: float3;
    public let faceIndices: CountableRange<Int32>;
    public let brushIndices: CountableRange<Int32>;
}

public struct BSPBrush {
    public let brushSideIndices: CountableRange<Int32>;
    public let textureIndex: Int32;
}

public struct BSPBrushSide {
    public let planeIndex: Int32;
    public let textureIndex: Int32;
}

public struct BSPVertex {
    public let position: float3;
    public let surfaceTextureCoord: float2;
    public let lightmapTextureCoord: float2;
    public let normal: float3;
    public let color: float4;
}

public func +(left: BSPVertex, right: BSPVertex) -> BSPVertex {
    return BSPVertex(
        position: left.position + right.position,
        surfaceTextureCoord: left.surfaceTextureCoord + right.surfaceTextureCoord,
        lightmapTextureCoord: left.lightmapTextureCoord + right.lightmapTextureCoord,
        normal: left.normal + right.normal,
        color: left.color + right.color
    )
}

public func *(left: BSPVertex, right: BSPVertex) -> BSPVertex {
    return BSPVertex(
        position: left.position * right.position,
        surfaceTextureCoord: left.surfaceTextureCoord * right.surfaceTextureCoord,
        lightmapTextureCoord: left.lightmapTextureCoord * right.lightmapTextureCoord,
        normal: left.normal * right.normal,
        color: left.color * right.color
    )
}

public func *(left: BSPVertex, right: Float) -> BSPVertex {
    return BSPVertex(
        position: left.position * right,
        surfaceTextureCoord: left.surfaceTextureCoord * right,
        lightmapTextureCoord: left.lightmapTextureCoord * right,
        normal: left.normal * right,
        color: left.color * right
    )
}


public struct BSPMeshVert {
    public let vertexIndexOffset: Int32;
}

public struct BSPEffect {
    public let name: String;
    public let brushIndex: Int32;
}

public struct BSPFace {
    public enum FaceType: Int32 {
        case polygon = 1, patch, mesh, billboard;
    }

    public let textureIndex: Int32;
    public let effectIndex: Int32?;
    public let type: FaceType;
    public let vertexIndices: CountableRange<Int32>;
    public let meshVertIndices: CountableRange<Int32>;
    public let lightmapIndex: Int32;
    public let lightmapStart: int2;
    public let lightmapSize: int2;
    public let lightmapOrigin: float3;
    public let lightmapSVector: float3;
    public let lightmapTVector: float3;
    public let normal: float3;
    public let size: int2;
}

public struct BSPLightmap {
    public let lightmap: Array<(UInt8, UInt8, UInt8)>;
}

public struct BSPLightVol {
    public let ambientColor: (UInt8, UInt8, UInt8);
    public let directionalColor: (UInt8, UInt8, UInt8);
    public let direction: (UInt8, UInt8);
}

public struct BSPVisdata {
    public let numVectors: Int32;
    public let vectorSize: Int32;
    public let vectors: Array<UInt8>;
}
