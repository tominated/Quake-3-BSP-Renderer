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

enum SourceBlendFunction {
    case One
    case Zero
    case DestColor
    case OneMinusDestColor
    case SourceAlpha
    case OneMinusSourceAlpha
}

enum DestBlendFunction {
    case One
    case Zero
    case SourceColor
    case OneMinusSourceColor
    case SourceAlpha
    case OneMinusSourceAlpha
}

enum BlendFunction {
    case Add
    case Blend
    case Filter
    case Explicit(SourceBlendFunction, DestBlendFunction)
}

enum Cull {
    case Front
    case Back
    case None
}

enum VertexDeform {
    case Wave(Float, Waveform) // Div, Wave
    case Normal(Float, Waveform) // Div, Wave
    case Bulge(Float, Float, Float) // Width, Height, Speed
    case Move(Float, Float, Float, Waveform) // X, Y, Z, Wave
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
    case Default
    case Wave(Waveform)
    case Portal
}

enum TextureCoordinateGenerator {
    case Vector(Float, Float, Float, Float, Float, Float) // SX, SY, SZ, TX, TY, TZ
    case Rotate(Float)
    case Scale(Float, Float)
    case Scroll(Float, Float)
    case Stretch(Waveform)
    case Turbulance(TurbulanceDescription)
}

enum DepthFunction {
    case LessThanOrEqual
    case Equal
}

struct Q3ShaderStage {
    let map: String? = nil
    let clamp: Bool = false
    let textureCoordinateGenerator: TextureCoordinateGenerator? = nil
    let rgbGenerator: RGBGenerator = .Identity
    let alphaGenerator: AlphaGenerator = .Default
    let blending: BlendFunction? = .Explicit(.One, .Zero)
    let textureCoordinateGenerators: Array<TextureCoordinateGenerator> = []
    let animationMaps: Array<String> = []
    let animationFrequency: Float = 0
    let depthFunction: DepthFunction = .LessThanOrEqual
    let depthWrite: Bool = true
}

struct Q3Shader {
    let name: String
    let cull: Cull
    // sky
    let blend: Bool
    let sort: Int
    let vertexDeforms: Array<VertexDeform>
    let stages: Array<Q3ShaderStage>
}