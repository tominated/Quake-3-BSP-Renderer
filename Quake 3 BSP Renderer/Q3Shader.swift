//
//  Q3Shader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 10/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import Metal

enum WaveformFunction {
    case sin
    case triangle
    case square
    case sawtooth
    case inverseSawtooth
    case noise
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

enum VertexDeform {
    case wave(spread: Float, waveform: Waveform)
    case normal(frequency: Float, amplitude: Float)
    case bulge(width: Float, height: Float, speed: Float)
    case move(x: Float, y: Float, z: Float, waveform: Waveform)
    case projectionShadow
    case autoSprite
    case autoSprite2
    case text // Ignoring the number for now
}

enum RGBGenerator {
    case identity
    case identityLighting
    case wave(Waveform)
    case vertex
    case lightingDiffuse
    case entity
    case oneMinusEntity
    case exactVertex
    case undefined
}

enum AlphaGenerator {
    case wave(Waveform)
    case constant(Float)
    case identity
    case entity
    case oneMinusEntity
    case vertex
    case lightingSpecular
    case oneMinusVertex
    case portal(Float)
}

enum TextureCoordinateGenerator {
    case base
    case lightmap
    case environment
    case vector(sx: Float, sy: Float, sz: Float, tx: Float, ty: Float, tz: Float)
}

enum TextureCoordinateMod {
    case rotate(degrees: Float)
    case scale(x: Float, y: Float)
    case scroll(x: Float, y: Float)
    case stretch(Waveform)
    case turbulance(TurbulanceDescription)
    case transform(m00: Float, m01: Float, m10: Float, m11: Float, t0: Float, t1: Float)
}

enum AlphaFunction: UInt8 {
    case gt0 = 0, lt128, ge128
}

enum DepthFunction {
    case lessThanOrEqual, equal
}

enum StageTexture {
    case texture(String)
    case textureClamp(String)
    case lightmap
    case white
    case animated(frequency: Float, Array<String>)
}

enum Sort {
    case portal
    case sky
    case opaque
    case decal
    case seeThrough
    case banner
    case additive
    case nearest
    case underwater
    case explicit(Int32)

    func order() -> Int32 {
        switch self {
        case .portal: return 1
        case .sky: return 2
        case .opaque: return 3
        case .decal: return 4
        case .seeThrough: return 5
        case .banner: return 6
        case .additive: return 9
        case .nearest: return 16
        case .underwater: return 8
        case .explicit(let x): return x
        }
    }
}

struct SkyParams {
    var farBox: String? = nil
    var cloudHeight: Float = 128
    var nearBox: String? = nil
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
    var map: StageTexture = .white
    var blending: (MTLBlendFactor, MTLBlendFactor)? = nil
    var textureCoordinateGenerator: TextureCoordinateGenerator = .base
    var rgbGenerator: RGBGenerator = .undefined
    var alphaGenerator: AlphaGenerator = .identity
    var alphaFunction: AlphaFunction? = nil
    var textureCoordinateMods: Array<TextureCoordinateMod> = []
    var depthFunction: MTLCompareFunction = .lessEqual
    var depthWrite: Bool = true

    func hasBlending() -> Bool {
        return blending != nil
    }

    func getRenderPipelineDescriptor(
        _ vertexFunction: MTLFunction,
        _ fragmentFunction: MTLFunction
    ) -> MTLRenderPipelineDescriptor {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        // Set Metal functions
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = MapMesh.vertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let colorAttachment = pipelineDescriptor.colorAttachments[0]

        colorAttachment?.pixelFormat = .bgra8Unorm_srgb

        if let (sourceBlend, destinationBlend) = blending {
            colorAttachment?.isBlendingEnabled = true
            colorAttachment?.sourceRGBBlendFactor = sourceBlend
            colorAttachment?.sourceAlphaBlendFactor = sourceBlend
            colorAttachment?.destinationRGBBlendFactor = destinationBlend
            colorAttachment?.destinationAlphaBlendFactor = destinationBlend
        }

        return pipelineDescriptor
    }

    func getDepthStencilDescriptor() -> MTLDepthStencilDescriptor {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()

        depthStencilDescriptor.depthCompareFunction = depthFunction
        depthStencilDescriptor.isDepthWriteEnabled = depthWrite

        return depthStencilDescriptor
    }

    func getSamplerDescriptor(_ mipmapsEnabled: Bool) -> MTLSamplerDescriptor {
        let samplerDescriptor = MTLSamplerDescriptor()

        samplerDescriptor.rAddressMode = .repeat
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.maxAnisotropy = 16

        if mipmapsEnabled {
            samplerDescriptor.mipFilter = .linear
        }

        switch map {
        case .textureClamp(_):
            samplerDescriptor.rAddressMode = .clampToEdge
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
        default: break
        }

        return samplerDescriptor
    }
}

struct Q3Shader {
    var name: String = ""
    var cull: MTLCullMode = .back
    var sky: SkyParams? = nil
    var sort: Sort = .opaque
    var mipmapsEnabled: Bool = true
    var vertexDeforms: Array<VertexDeform> = []
    var stages: Array<Q3ShaderStage> = []

    // This is required to allow instantiation with no arguments
    init() {}

    // Create a default shader for a texture
    init(textureName: String) {
        name = textureName

        var diffuseStage = Q3ShaderStage()
        diffuseStage.map = .texture(name)
        diffuseStage.textureCoordinateGenerator = .base
        diffuseStage.rgbGenerator = .identityLighting

        var lightmapStage = Q3ShaderStage()
        lightmapStage.map = .lightmap
        lightmapStage.blending = (.destinationColor, .zero)
        lightmapStage.depthFunction = .equal
        lightmapStage.textureCoordinateGenerator = .lightmap
        lightmapStage.rgbGenerator = .identityLighting

        stages.append(diffuseStage)
        stages.append(lightmapStage)
    }

    func hasBlending() -> Bool {
        for stage in stages {
            if stage.hasBlending() {
                return true
            }
        }

        return false
    }
}
