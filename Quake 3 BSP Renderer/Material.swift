//
//  Material.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 23/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import MetalKit

private let whiteTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
    .RGBA8Unorm,
    width: 1,
    height: 1,
    mipmapped: false
)

struct Material {
    private enum StageTexture {
        case Static(MTLTexture)
        case Animated(frequency: Float, Array<MTLTexture>)
        case Lightmap
    }
    
    private struct MaterialStage {
        let pipelineState: MTLRenderPipelineState
        let texture: Material.StageTexture
    }
    
    private var textureLoader: Q3TextureLoader
    private var stages: Array<MaterialStage> = []
    private var cull: MTLCullMode
    
    init(shader: Q3Shader, device: MTLDevice, textureLoader: Q3TextureLoader) throws {
        self.textureLoader = textureLoader
        cull = shader.cull
        
        let library = device.newDefaultLibrary()!
        let vertexFunction = library.newFunctionWithName("renderVert")
        let fragmentFunction = library.newFunctionWithName("renderFrag")
        let lightmapFragmentFunction = library.newFunctionWithName("renderFragLM")
        
        let whiteTexture = textureLoader.loadWhiteTexture()
        
        for stage in shader.stages {
            // Set up pipeline state
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = MapMesh.vertexDescriptor()
            pipelineDescriptor.sampleCount = 2
            pipelineDescriptor.depthAttachmentPixelFormat = .Depth32Float
            
            let colorAttachment = pipelineDescriptor.colorAttachments[0]

            colorAttachment.pixelFormat = .BGRA8Unorm
            
            if let (sourceBlend, destinationBlend) = stage.blending {
                colorAttachment.blendingEnabled = true
                colorAttachment.sourceRGBBlendFactor = sourceBlend
                colorAttachment.sourceAlphaBlendFactor = sourceBlend
                colorAttachment.destinationRGBBlendFactor = destinationBlend
                colorAttachment.destinationAlphaBlendFactor = destinationBlend
            }
            
            var texture: Material.StageTexture = .Static(whiteTexture)
            
            switch stage.map {
            case .Texture(let path):
                texture = .Static(textureLoader.loadTexture(path) ?? whiteTexture)
                
            case .TextureClamp(let path):
                texture = .Static(textureLoader.loadTexture(path) ?? whiteTexture)
                
            case .Animated(let f, let paths):
                let textures = paths.map { path in
                    return textureLoader.loadTexture(path) ?? whiteTexture
                }
                
                texture = .Animated(frequency: f, textures)
            
            case .Lightmap:
                pipelineDescriptor.fragmentFunction = lightmapFragmentFunction
                
            default: break
            }
            
            let pipelineState = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
            
            stages.append(
                MaterialStage(
                    pipelineState: pipelineState,
                    texture: texture
                )
            )
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder, time: Float, indexBuffer: MTLBuffer, indexCount: Int, lightmap: MTLTexture) {
        encoder.setCullMode(.None)
        
        for stage in stages {
            
            // Set pipeline state
            encoder.setRenderPipelineState(stage.pipelineState)
            
            // Set the texture
            switch stage.texture {
            case .Static(let texture):
                encoder.setFragmentTexture(texture, atIndex: 0)
                
            case .Animated(let frequency, let textures):
                let index = Int(time * frequency) % textures.count
                encoder.setFragmentTexture(textures[index], atIndex: 0)
            
            case .Lightmap:
                encoder.setFragmentTexture(lightmap, atIndex: 0)
            }
            
            encoder.drawIndexedPrimitives(
                .Triangle,
                indexCount: indexCount,
                indexType: .UInt32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        }
    }
}