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
        let depthStencilState: MTLDepthStencilState
        let samplerState: MTLSamplerState
        let texture: Material.StageTexture
    }
    
    private var textureLoader: Q3TextureLoader
    private var stages: Array<MaterialStage> = []
    private var cull: MTLCullMode
    
    init(shader: Q3Shader, device: MTLDevice, textureLoader: Q3TextureLoader) throws {
        self.textureLoader = textureLoader
        cull = shader.cull
        
        let whiteTexture = textureLoader.loadWhiteTexture()
        
        for stage in shader.stages {
            let str = buildShaderLibrary(shader, stage: stage)
            let library = try! device.newLibraryWithSource(str, options: nil)
            let vertexFunction = library.newFunctionWithName("renderVert")
            let fragmentFunction = library.newFunctionWithName("renderFrag")
            
            // Set up pipeline and depth state
            let pipelineDescriptor = stage.getRenderPipelineDescriptor(vertexFunction!, fragmentFunction!)
            let depthStencilDescriptor = stage.getDepthStencilDescriptor()
            let samplerDescriptor = stage.getSamplerDescriptor(shader.mipmapsEnabled)
            
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
                texture = .Lightmap
                
            default: break
            }
            
            let pipelineState = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
            let depthStencilState = device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
            let samplerState = device.newSamplerStateWithDescriptor(samplerDescriptor)
            
            stages.append(
                MaterialStage(
                    pipelineState: pipelineState,
                    depthStencilState: depthStencilState,
                    samplerState: samplerState,
                    texture: texture
                )
            )
        }
    }
    
    func renderWithEncoder(encoder: MTLRenderCommandEncoder, time: Float, indexBuffer: MTLBuffer, indexCount: Int, lightmap: MTLTexture) {
        encoder.setCullMode(cull)
        
        for stage in stages {
            
            // Set pipeline and depth state
            encoder.setRenderPipelineState(stage.pipelineState)
            encoder.setDepthStencilState(stage.depthStencilState)
            encoder.setFragmentSamplerState(stage.samplerState, atIndex: 0)
            
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