//
//  ShaderBuilder.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 10/03/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import Metal
import Mustache

func buildShaderLibrary(shader: Q3Shader, stage: Q3ShaderStage) -> String {
    let template = try! Template(named: "shaderTemplate")
    
    let data = [
        "textureCoordinateGenerator": Box(stage.textureCoordinateGenerator),
        "rgbGenerator": Box(stage.rgbGenerator),
        "alphaFunction": Box(stage.alphaFunction)
    ]
    
    return try! template.render(Box(data))
}

extension TextureCoordinateGenerator: MustacheBoxable {
    var mustacheBox: MustacheBox {
        switch self {
        case .Lightmap: return Box("vert.lightmapCoord")
        default: return Box("float2(0, 1) - vert.textureCoord")
        }
    }
}

extension RGBGenerator: MustacheBoxable {
    var mustacheBox: MustacheBox {
        switch self {
        case .Vertex: return Box("half4(vert.color)")
        default: return Box("half4(1,1,1,1)")
        }
    }
}

extension AlphaFunction: MustacheBoxable {
    var mustacheBox: MustacheBox {
        var condition = ""
        
        switch self {
        case .GT0: condition = "<= 0"
        case .LT128: condition = ">= 0.5"
        case .GE128: condition = "< 0.5"
        }
        
        return Box("if (diffuse[3] \(condition)) discard_fragment();")
    }
}

class ShaderBuilder {
    let device: MTLDevice
    let template: Template
    
    init(device: MTLDevice) {
        self.device = device
        template = try! Template(named: "shaderTemplate")
    }
    
    private func buildShaderLibrary(shader: Q3Shader, stage: Q3ShaderStage) -> MTLLibrary {
        return try! device.newLibraryWithSource(
            buildShaderSource(shader, stage),
            options: nil
        )
    }
    
    private func buildShaderSource(shader: Q3Shader, _ stage: Q3ShaderStage) -> String {
        return try! template.render()
    }
}