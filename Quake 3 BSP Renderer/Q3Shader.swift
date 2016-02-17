//
//  Q3Shader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 10/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation


enum WaveformFunction {
    case Sin
    case Triangle
    case Square
    case Sawtooth
    case InverseSawtooth
}

struct Waveform {
    let function: WaveformFunction
    let base: Float
    let amplitude: Float
    let phase: Float
    let frequency: Float
}

struct TurbulanceDescription {
    let base: Float
    let amplitude: Float
    let phase: Float
    let frequency: Float
}

enum SourceBlendMode {
    case One
    case Zero
    case DestColor
    case OneMinusDestColor
    case SourceAlpha
    case OneMinusSourceAlpha
    case DestAlpha
    case OneMinusDestAlpha
    case SourceAlphaSaturate
}

enum DestBlendMode {
    case One
    case Zero
    case SourceAlpha
    case OneMinusSourceAlpha
    case DestAlpha
    case OneMinusDestAlpha
    case SourceColor
    case OneMinusSourceColor
}

enum Cull {
    case Front
    case Back
    case None
}

enum VertexDeform {
    case Wave(divisions: Float, waveform: Waveform)
    case Normal(divisions: Float, waveform: Waveform)
    case Bulge(width: Float, height: Float, speed: Float)
    case Move(x: Float, y: Float, z: Float, waveform: Waveform)
    case AutoSprite
    case AutoSprite2
}

enum RGBGenerator {
    case Identity
    case IdentityLighting
    case Wave(Waveform)
    case Vertex
    case LightingDiffuse
}

enum AlphaGenerator {
    case Wave(Waveform)
    case Constant(Float)
    case Identity
    case Entity
    case OneMinusEntity
    case Vertex
    case LightingSpecular
    case OneMinusVertex
    case Portal
}

enum TextureCoordinateMod {
    case Rotate(degrees: Float)
    case Scale(x: Float, y: Float)
    case Scroll(x: Float, y: Float)
    case Stretch(Waveform)
    case Turbulance(TurbulanceDescription)
    case Transform(m00: Float, m01: Float, m10: Float, m11: Float, t0: Float, t1: Float)
}

enum TextureCoordinateGenerator {
    case Base
    case Lightmap
    case Environment
    case Vector(sx: Float, sy: Float, sz: Float, tx: Float, ty: Float, tz: Float)
}

enum AlphaFunction {
    case GT0
    case LT128
    case GE128
}

enum DepthFunction {
    case LessThanOrEqual
    case Equal
}

enum Sort {
    case Portal
    case Sky
    case Opaque
    case Decal
    case SeeThrough
    case Banner
    case Additive
    case Nearest
    case Underwater
    case Explicit(Int32)
    
    func order() -> Int32 {
        switch self {
        case .Portal: return 1
        case .Sky: return 2
        case .Opaque: return 3
        case .Decal: return 4
        case .SeeThrough: return 5
        case .Banner: return 6
        case .Additive: return 9
        case .Nearest: return 16
        case .Underwater: return 8
        case .Explicit(let x): return x
        }
    }
}

extension Sort: Equatable {}
func ==(lhs: Sort, rhs: Sort) -> Bool {
    return lhs.order() == rhs.order()
}

extension Sort: Comparable {}
func <(lhs: Sort, rhs: Sort) -> Bool {
    return lhs.order() < rhs.order()
}


struct Q3ShaderStage {
    var map: String? = nil
    var clamp: Bool = false
    var textureCoordinateGenerator: TextureCoordinateGenerator = .Base
    var rgbGenerator: RGBGenerator = .Identity
    var alphaGenerator: AlphaGenerator = .Identity
    var alphaFunction: AlphaFunction? = nil
    var blendSource: SourceBlendMode = .One
    var blendDest: DestBlendMode = .Zero
    var textureCoordinateMods: Array<TextureCoordinateMod> = []
    var animationMaps: Array<String> = []
    var animationFrequency: Float = 0
    var depthFunction: DepthFunction = .LessThanOrEqual
    var depthWrite: Bool = true
}

struct Q3Shader {
    var name: String = ""
    var cull: Cull = .Front
    // sky
    var blend: Bool = false
    var sort: Sort = .Opaque
    var vertexDeforms: Array<VertexDeform> = []
    var stages: Array<Q3ShaderStage> = []
}