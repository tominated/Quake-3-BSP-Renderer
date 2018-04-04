//
//  Material.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 23/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import MetalKit

private let whiteTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm,
    width: 1,
    height: 1,
    mipmapped: false
)

struct Material {
    fileprivate enum StageTexture {
        case `static`(MTLTexture)
        case animated(frequency: Float, Array<MTLTexture>)
        case lightmap
    }
    
    fileprivate struct MaterialStage {
        let pipelineState: MTLRenderPipelineState
        let depthStencilState: MTLDepthStencilState
        let samplerState: MTLSamplerState
        let texture: Material.StageTexture
    }
    
    fileprivate var textureLoader: Q3TextureLoader
    fileprivate var stages: Array<MaterialStage> = []
    fileprivate var cull: MTLCullMode
    private let name: String
    
    init(shader: Q3Shader, device: MTLDevice, shaderBuilder: ShaderBuilder, textureLoader: Q3TextureLoader) throws {
        self.textureLoader = textureLoader
        cull = shader.cull
        name = shader.name
        
        let whiteTexture = textureLoader.loadWhiteTexture()
        
        for stage in shader.stages {
            let library = shaderBuilder.buildShaderLibrary(shader, stage)
            let vertexFunction = library.makeFunction(name: "renderVert")
            let fragmentFunction = library.makeFunction(name: "renderFrag")
            
            // Set up pipeline and depth state
            let pipelineDescriptor = stage.getRenderPipelineDescriptor(vertexFunction!, fragmentFunction!)
            let depthStencilDescriptor = stage.getDepthStencilDescriptor()
            let samplerDescriptor = stage.getSamplerDescriptor(shader.mipmapsEnabled)
            
            var texture: Material.StageTexture = .static(whiteTexture)
            
            switch stage.map {
            case .texture(let path):
                texture = .static(textureLoader.loadTexture(path) ?? whiteTexture)
                
            case .textureClamp(let path):
                texture = .static(textureLoader.loadTexture(path) ?? whiteTexture)
                
            case .animated(let f, let paths):
                let textures = paths.map { path in
                    return textureLoader.loadTexture(path) ?? whiteTexture
                }
                
                texture = .animated(frequency: f, textures)
            
            case .lightmap:
                texture = .lightmap
                
            default: break
            }
            
            let pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            let samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
            
            stages.append(
                MaterialStage(
                    pipelineState: pipelineState,
                    depthStencilState: depthStencilState!,
                    samplerState: samplerState!,
                    texture: texture
                )
            )
        }
    }
    
    func renderWithEncoder(_ encoder: MTLRenderCommandEncoder, time: Float, indexBuffer: MTLBuffer, indexCount: Int, lightmap: MTLTexture) {
        encoder.pushDebugGroup("Material(\(self.name))")
        encoder.setCullMode(cull)
        
        for (i, stage) in stages.enumerated() {
            encoder.pushDebugGroup("stage \(i)")
            
            // Set pipeline and depth state
            encoder.setRenderPipelineState(stage.pipelineState)
            encoder.setDepthStencilState(stage.depthStencilState)
            encoder.setFragmentSamplerState(stage.samplerState, index: 0)
            
            // Set the texture
            switch stage.texture {
            case .static(let texture):
                encoder.setFragmentTexture(texture, index: 0)
                
            case .animated(let frequency, let textures):
                let index = Int(time * frequency) % textures.count
                encoder.setFragmentTexture(textures[index], index: 0)
            
            case .lightmap:
                encoder.setFragmentTexture(lightmap, index: 0)
            }
            
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
            encoder.popDebugGroup()
        }
        encoder.popDebugGroup()
    }
}
