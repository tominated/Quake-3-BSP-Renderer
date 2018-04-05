//
//  ShaderGenerator.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 04/04/2018.
//  Copyright © 2018 Thomas Brunoli. All rights reserved.
//

import Foundation
import Metal

class ShaderGenerator {
    let shader: Q3Shader
    let stage: Q3ShaderStage

    static private let vertexInDef = """
    struct VertexIn
    {
        float4 position [[attribute(0)]];
        float4 normal [[attribute(1)]];
        float4 color [[attribute(2)]];
        float2 textureCoord [[attribute(3)]];
        float2 lightmapCoord [[attribute(4)]];
    };
    """

    static private let vertexOutDef = """
    struct VertexOut
    {
        float4 position [[position]];
        float4 normal;
        float4 color;
        float2 textureCoord;
    };
    """

    static private let uniformsDef = """
    struct Uniforms
    {
        float time;
        float4x4 viewMatrix;
        float4x4 projectionMatrix;
    };
    """

    static private let vertexFunctionDef = """
    vertex VertexOut renderVert(VertexIn in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(1)]],
                                uint vid [[vertex_id]])
    """

    static private let fragmentFunctionDef = """
    fragment half4 renderFrag(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              texture2d<half> tex [[texture(0)]],
                              sampler smp [[sampler(0)]])
    """

    init(shader: Q3Shader, stage: Q3ShaderStage) {
        self.shader = shader
        self.stage = stage
    }

    public func buildShader() -> String {
        return """
        #include <metal_stdlib>
        using namespace metal;

        \(ShaderGenerator.vertexInDef)
        \(ShaderGenerator.vertexOutDef)
        \(ShaderGenerator.uniformsDef)

        \(buildVertexFunction())
        \(buildFragmentFunction())
        """
    }

    private func buildVertexFunction() -> String {
        return """
        \(ShaderGenerator.vertexFunctionDef) {
            VertexOut out;
            float3 position = in.position.xyz;

            \(buildVertexDeforms())

            float4 worldPosition = uniforms.viewMatrix * float4(position, 1.0);
            float2 textureCoord = \(buildTextureCoordinateGenerator());

            \(buildTextureCoordinateMods())

            out.position = uniforms.projectionMatrix * worldPosition;
            out.normal = float4(in.normal);
            out.color = float4(in.color);
            out.textureCoord = textureCoord;

            return out;
        }
        """
    }

    private func buildFragmentFunction() -> String {
        return """
        \(ShaderGenerator.fragmentFunctionDef) {
            half4 diffuse = tex.sample(smp, in.textureCoord);

            \(buildRGBGenerator())
            \(buildAlphaGenerator())
            \(buildAlphaFunction())

            return half4(color.rgb, alpha);
        }
        """
    }

    private func buildTextureCoordinateGenerator() -> String {
        switch stage.textureCoordinateGenerator {
            case .lightmap: return "in.lightmapCoord"
            default: return "in.textureCoord"
        }
    }

    private func buildRGBGenerator() -> String {
        switch stage.rgbGenerator {
        case .vertex:
            return "half3 color = half3(diffuse.rgb * half3(in.color.rgb));"

        case .wave(let waveform):
            return """
            \(buildWaveform(waveform, name: "rgbWave"))
            half3 color = diffuse.rgb * rgbWave;
            """

        default:
            return "half3 color = half3(diffuse.rgb);"
        }
    }

    private func buildAlphaGenerator() -> String {
        switch stage.alphaGenerator {
        case .constant(let a):
            return "float alpha = \(a)F;"

        case .wave(let waveform):
            return buildWaveform(waveform, name: "alpha")

        default:
            return "float alpha = diffuse.a;"
        }
    }

    private func buildAlphaFunction() -> String {
        guard let alphaFunction = stage.alphaFunction else {
            return ""
        }

        var condition = ""

        switch alphaFunction {
        case .gt0: condition = "<= 0F"
        case .lt128: condition = ">= 0.5F"
        case .ge128: condition = "< 0.5F"
        }

        return "if (alpha \(condition)) discard_fragment();"
    }

    private func buildWaveform(_ waveform: Waveform, name: String) -> String {
        switch waveform.function {
        case .sawtooth:
            return """
            float \(name) =
                \(waveform.base)F +
                fract(\(waveform.phase)F + uniforms.time * \(waveform.frequency)F) *
                \(waveform.amplitude)F;
            """

        case .sin:
            return """
            float \(name) =
                \(waveform.base)F +
                sin((\(waveform.phase)F + uniforms.time * \(waveform.frequency)F) * M_PI_F * 2) *
                \(waveform.amplitude)F;
            """

        case .square:
            return """
            float \(name) =
                \(waveform.base)F +
                ((((int(floor((\(waveform.phase)F + uniforms.time * \(waveform.frequency)F) * 2.0) + 1.0)) % 2) * 2.0) - 1.0) *
                \(waveform.amplitude)F;
            """

        case .triangle:
            return """
            float \(name) =
                \(waveform.base)F +
                abs(2.0 * fract((\(waveform.phase)F + uniforms.time * \(waveform.frequency)F)) - 1.0) *
                \(waveform.amplitude)F;
            """

        default:
            return "float \(name) = \(waveform.base)F;"
        }
    }

    private func buildVertexDeforms() -> String {
        var deforms = ""

        for vertexDeform in shader.vertexDeforms {
            switch vertexDeform {
            case .wave(let spread, let waveform):
                deforms.append("""
                {
                    \(buildWaveform(waveform, name: "deformWave"))
                    float offset = (in.position.x + in.position.y + in.position.z) * \(spread)F;
                    position *= in.normal.xyz * deformWave;
                }
                """)

            default: continue
            }
        }

        return deforms
    }

    private func buildTextureCoordinateMods() -> String {
        var texCoordMods = ""

        for texCoordMod in stage.textureCoordinateMods {
            switch texCoordMod {
            case .rotate(let degrees):
                texCoordMods.append("""
                {
                    float r = \(degrees)F * uniforms.time;
                    textureCoord -= float2(0.5, 0.5);
                    textureCoord = float2(
                        textureCoord[0] * cos(r) - textureCoord[1] * sin(r),
                        textureCoord[1] * cos(r) + textureCoord[0] * sin(r)
                    );
                    textureCoord += float2(0.5, 0.5);
                }
                """)

            case .scale(let x, let y):
                texCoordMods.append("""
                {
                    textureCoord *= float2(\(x)F, \(y)F);
                }
                """)

            case .scroll(let x, let y):
                texCoordMods.append("""
                {
                    textureCoord += float2(\(x)F * uniforms.time, \(y)F * uniforms.time);
                }
                """)

            case .stretch(let waveform):
                texCoordMods.append("""
                {
                    \(buildWaveform(waveform, name: "stretchWave"))
                    stretchWave = 1.0F / stretchWave;
                    textureCoord *= stretchWave;
                    textureCoord += float2(0.5F - (0.5F * stretchWave), 0.5F - (0.5F * stretchWave));
                }
                """)

            default: continue
            }
        }

        return texCoordMods
    }
}
