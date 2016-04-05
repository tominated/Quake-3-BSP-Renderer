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
    case Sin
    case Triangle
    case Square
    case Sawtooth
    case InverseSawtooth
    case Noise
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
    case Wave(spread: Float, waveform: Waveform)
    case Normal(frequency: Float, amplitude: Float)
    case Bulge(width: Float, height: Float, speed: Float)
    case Move(x: Float, y: Float, z: Float, waveform: Waveform)
    case ProjectionShadow
    case AutoSprite
    case AutoSprite2
    case Text // Ignoring the number for now
}

enum RGBGenerator {
    case Identity
    case IdentityLighting
    case Wave(Waveform)
    case Vertex
    case LightingDiffuse
    case Entity
    case OneMinusEntity
    case ExactVertex
    case Undefined
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
    case Portal(Float)
}

enum TextureCoordinateGenerator {
    case Base
    case Lightmap
    case Environment
    case Vector(sx: Float, sy: Float, sz: Float, tx: Float, ty: Float, tz: Float)
}

enum TextureCoordinateMod {
    case Rotate(degrees: Float)
    case Scale(x: Float, y: Float)
    case Scroll(x: Float, y: Float)
    case Stretch(Waveform)
    case Turbulance(TurbulanceDescription)
    case Transform(m00: Float, m01: Float, m10: Float, m11: Float, t0: Float, t1: Float)
}

enum AlphaFunction: UInt8 {
    case GT0 = 0, LT128, GE128
}

enum DepthFunction {
    case LessThanOrEqual, Equal
}

enum StageTexture {
    case Texture(String)
    case TextureClamp(String)
    case Lightmap
    case White
    case Animated(frequency: Float, Array<String>)
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
    var map: StageTexture = .White
    var blending: (MTLBlendFactor, MTLBlendFactor)? = nil
    var textureCoordinateGenerator: TextureCoordinateGenerator = .Base
    var rgbGenerator: RGBGenerator = .Undefined
    var alphaGenerator: AlphaGenerator = .Identity
    var alphaFunction: AlphaFunction? = nil
    var textureCoordinateMods: Array<TextureCoordinateMod> = []
    var depthFunction: MTLCompareFunction = .LessEqual
    var depthWrite: Bool = true
    
    func hasBlending() -> Bool {
        return blending != nil
    }
    
    func getRenderPipelineDescriptor(
        vertexFunction: MTLFunction,
        _ fragmentFunction: MTLFunction
    ) -> MTLRenderPipelineDescriptor {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Set Metal functions
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = MapMesh.vertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat = .Depth32Float
        
        let colorAttachment = pipelineDescriptor.colorAttachments[0]
        
        colorAttachment.pixelFormat = .BGRA8Unorm
        
        if let (sourceBlend, destinationBlend) = blending {
            colorAttachment.blendingEnabled = true
            colorAttachment.sourceRGBBlendFactor = sourceBlend
            colorAttachment.sourceAlphaBlendFactor = sourceBlend
            colorAttachment.destinationRGBBlendFactor = destinationBlend
            colorAttachment.destinationAlphaBlendFactor = destinationBlend
        }
        
        return pipelineDescriptor
    }
    
    func getDepthStencilDescriptor() -> MTLDepthStencilDescriptor {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        
        depthStencilDescriptor.depthCompareFunction = depthFunction
        depthStencilDescriptor.depthWriteEnabled = depthWrite
        
        return depthStencilDescriptor
    }
    
    func getSamplerDescriptor(mipmapsEnabled: Bool) -> MTLSamplerDescriptor {
        let samplerDescriptor = MTLSamplerDescriptor()
        
        samplerDescriptor.rAddressMode = .Repeat
        samplerDescriptor.sAddressMode = .Repeat
        samplerDescriptor.tAddressMode = .Repeat
        samplerDescriptor.minFilter = .Linear
        samplerDescriptor.magFilter = .Linear
        
        if mipmapsEnabled {
            samplerDescriptor.mipFilter = .Linear
        }
        
        switch map {
        case .TextureClamp(_):
            samplerDescriptor.rAddressMode = .ClampToEdge
            samplerDescriptor.sAddressMode = .ClampToEdge
            samplerDescriptor.tAddressMode = .ClampToEdge
        default: break
        }
        
        return samplerDescriptor
    }
}

struct Q3Shader {
    var name: String = ""
    var cull: MTLCullMode = .Back
    var sky: SkyParams? = nil
    var sort: Sort = .Opaque
    var mipmapsEnabled: Bool = true
    var vertexDeforms: Array<VertexDeform> = []
    var stages: Array<Q3ShaderStage> = []
    
    // This is required to allow instantiation with no arguments
    init() {}
    
    // Create a default shader for a texture
    init(textureName: String) {
        name = textureName
        
        var diffuseStage = Q3ShaderStage()
        diffuseStage.map = .Texture(name)
        diffuseStage.textureCoordinateGenerator = .Base
        diffuseStage.rgbGenerator = .IdentityLighting
        
        var lightmapStage = Q3ShaderStage()
        lightmapStage.map = .Lightmap
        lightmapStage.blending = (.DestinationColor, .Zero)
        lightmapStage.depthFunction = .Equal
        lightmapStage.textureCoordinateGenerator = .Lightmap
        lightmapStage.rgbGenerator = .IdentityLighting
        
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