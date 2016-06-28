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

class ShaderBuilder {
    let device: MTLDevice
    let repo: TemplateRepository
    
    init(device: MTLDevice) {
        self.device = device
        
        repo = TemplateRepository(
            bundle: NSBundle.mainBundle(),
            templateExtension: "mustache",
            encoding: NSASCIIStringEncoding
        )
        
        repo.configuration.contentType = .Text
    }
    
    func buildShaderLibrary(shader: Q3Shader, _ stage: Q3ShaderStage) -> MTLLibrary {
        return try! device.newLibraryWithSource(
            buildShaderSource(shader, stage),
            options: nil
        )
    }
    
    private func buildShaderSource(shader: Q3Shader, _ stage: Q3ShaderStage) -> String {
        let template = try! repo.template(named: "main")
        
        let data = Box([
            "textureCoordinateGenerator": Box(buildTextureCoordinateGenerator(stage.textureCoordinateGenerator)),
            "rgbGenerator": Box(buildRGBGenerator(stage.rgbGenerator)),
            "alphaGenerator": Box(buildAlphaGenerator(stage.alphaGenerator)),
            "alphaFunction": Box(buildAlphaFunction(stage.alphaFunction)),
            "textureCoordinateMods": Box(stage.textureCoordinateMods.map(buildTextureCoordinateMod))
        ])
        
        return try! template.render(data)
    }
    
    private func buildTextureCoordinateGenerator(val: TextureCoordinateGenerator) -> String {
        switch val {
        case .Lightmap: return "in.lightmapCoord"
        default: return "in.textureCoord"
        }
    }
    
    private func buildRGBGenerator(val: RGBGenerator) -> String {
        switch val {
        case .Vertex: return "half4(in.color)"
        default: return "half4(1,1,1,1)"
        }
    }
    
    private func buildAlphaGenerator(val: AlphaGenerator) -> String {
        return "diffuse[3]"
    }
    
    private func buildAlphaFunction(val: AlphaFunction?) -> String {
        guard let alphaFunc = val else {
            return ""
        }
        
        var condition = ""
        
        switch alphaFunc {
        case .GT0: condition = "<= 0"
        case .LT128: condition = ">= 0.5"
        case .GE128: condition = "< 0.5"
        }
        
        return "if (alpha \(condition)) discard_fragment();"
    }
    
    private func buildWaveform(name: String, val: Waveform) -> MustacheBox {
        let templateName: String = {
            switch val.function {
            case .Sin: return "waveformSin"
            case .Triangle: return "waveformTriangle"
            case .Square: return "waveformSquare"
            case .Sawtooth: return "waveformSawtooth"
            case .InverseSawtooth: return "waveformInverseSawtooth"
            case .Noise: return "waveformNoise"
            }
        }()
        
        let template = try! repo.template(named: templateName)
        
        return Box([
            "template": template,
            "name": name,
            "base": val.base,
            "amplitude": val.amplitude,
            "phase": val.phase,
            "frequency": val.frequency
        ])
    }
    
    private func buildTextureCoordinateMod(val: TextureCoordinateMod) -> MustacheBox {
        switch val {
        case .Rotate(let degrees):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModRotate"),
                "angle": degrees
            ])
        case .Scale(let x, let y):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModScale"),
                "x": x,
                "y": y
            ])
        case .Scroll(let x, let y):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModScroll"),
                "x": x,
                "y": y
            ])
        case .Stretch(let waveform):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModStretch"),
                "waveform": buildWaveform("stretchWave", val: waveform)
            ])
        default:
            return Box("")
        }
    }
}