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
            bundle: Bundle.main,
            templateExtension: "mustache",
            encoding: String.Encoding.ascii
        )
        
        repo.configuration.contentType = .text
    }
    
    func buildShaderLibrary(_ shader: Q3Shader, _ stage: Q3ShaderStage) -> MTLLibrary {
        return try! device.makeLibrary(
            source: buildShaderSource(shader, stage),
            options: nil
        )
    }
    
    private func buildShaderSource(_ shader: Q3Shader, _ stage: Q3ShaderStage) -> String {
        let template = try! repo.template(named: "main")
        
        let data = Box([
            "textureCoordinateGenerator": Box(buildTextureCoordinateGenerator(val: stage.textureCoordinateGenerator)),
            "rgbGenerator": Box(buildRGBGenerator(val: stage.rgbGenerator)),
            "alphaGenerator": Box(buildAlphaGenerator(val: stage.alphaGenerator)),
            "alphaFunction": Box(buildAlphaFunction(val:stage.alphaFunction)),
            "vertexDeforms": Box(shader.vertexDeforms.map(buildVertexDeform)),
            "textureCoordinateMods": Box(stage.textureCoordinateMods.map(buildTextureCoordinateMod))
        ] as [String: Any])
        
        return try! template.render(data)
    }
    
    private func buildTextureCoordinateGenerator(val: TextureCoordinateGenerator) -> String {
        switch val {
        case .lightmap: return "in.lightmapCoord"
        default: return "in.textureCoord * float2(1.0, -1.0)"
        }
    }
    
    private func buildRGBGenerator(val: RGBGenerator) -> MustacheBox {
        switch val {
        case .vertex:
            return Box([
                "template": try! repo.template(named: "rgbGeneratorVertex")
            ])
        case .wave(let waveform):
            return Box([
                "template": try! repo.template(named: "rgbGeneratorWave"),
                "waveform": buildWaveform(name: "rgbWave", val: waveform)
            ] as [String: Any])
        default:
            return Box([
                "template": try! repo.template(named: "rgbGeneratorDefault")
            ])
        }
    }
    
    private func buildAlphaGenerator(val: AlphaGenerator) -> MustacheBox {
        switch val {
        case .constant(let a): return Box("float alpha = \(a);")
        case .wave(let waveform): return buildWaveform(name: "alpha", val: waveform)
        default: return Box("float alpha = diffuse.a;")
        }
    }
    
    private func buildAlphaFunction(val: AlphaFunction?) -> MustacheBox {
        guard let alphaFunc = val else {
            return Box(nil)
        }
        
        var condition = ""
        
        switch alphaFunc {
        case .gt0: condition = "<= 0"
        case .lt128: condition = ">= 0.5"
        case .ge128: condition = "< 0.5"
        }
        
        return Box("if (alpha \(condition)) discard_fragment();")
    }
    
    private func buildWaveform(name: String, val: Waveform) -> MustacheBox {
        let templateName: String = {
            switch val.function {
            case .sin: return "waveformSin"
            case .triangle: return "waveformTriangle"
            case .square: return "waveformSquare"
            case .sawtooth: return "waveformSawtooth"
            case .inverseSawtooth: return "waveformInverseSawtooth"
            case .noise: return "waveformNoise"
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
    
    private func buildVertexDeform(val: VertexDeform) -> MustacheBox {
        switch val {
        case .wave(let spread, let waveform):
            return Box([
                "template": try! repo.template(named: "vertexDeformWave"),
                "waveform": buildWaveform(name: "deformWave", val: waveform),
                "spread": spread
            ] as [String: Any])
        default:
            return Box(nil)
        }
    }
    
    private func buildTextureCoordinateMod(val: TextureCoordinateMod) -> MustacheBox {
        switch val {
        case .rotate(let degrees):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModRotate"),
                "angle": degrees
            ])
        case .scale(let x, let y):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModScale"),
                "x": x,
                "y": y
            ])
        case .scroll(let x, let y):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModScroll"),
                "x": x,
                "y": y
            ])
        case .stretch(let waveform):
            return Box([
                "template": try! repo.template(named: "textureCoordinateModStretch"),
                "waveform": buildWaveform(name: "stretchWave", val: waveform)
            ] as [String: Any])
        default:
            return Box("")
        }
    }
}
