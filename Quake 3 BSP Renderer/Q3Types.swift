//
//  Q3Types.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import simd

struct Q3Vertex {
    var position: float4 = float4(0, 0, 0, 0)
    var normal: float4 = float4(0, 0, 0, 0)
    var color: float4 = float4(0, 0, 0, 0)
    var textureCoord: float2 = float2(0, 0)
    var lightmapCoord: float2 = float2(0, 0)
}

func +(left: Q3Vertex, right: Q3Vertex) -> Q3Vertex {
    return Q3Vertex(
        position: left.position + right.position,
        normal: left.normal + right.normal,
        color: left.color + right.color,
        textureCoord: left.textureCoord + right.textureCoord,
        lightmapCoord: left.lightmapCoord + right.lightmapCoord
    )
}

func *(left: Q3Vertex, right: Float) -> Q3Vertex {
    return Q3Vertex(
        position: left.position * right,
        normal: left.normal * right,
        color: left.color * right,
        textureCoord: left.textureCoord * right,
        lightmapCoord: left.lightmapCoord * right
    )
}

typealias Q3Lightmap = Array<(UInt8, UInt8, UInt8, UInt8)>

enum Q3FaceType: Int {
    case Polygon = 1, Patch = 2, Mesh = 3, Billboard = 4
}

struct Q3Face {
    let textureName: String
    let lightmapIndex: Int
    let vertexIndices: Array<UInt32>
}