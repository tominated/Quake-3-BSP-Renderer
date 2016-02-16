//
//  Q3ShaderParser.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation

class Q3ShaderParser {
    enum Q3ShaderParserError: ErrorType {
        case InvalidSourceBlendMode(got: String?)
        case InvalidDestBlendMode(got: String?)
        case InvalidWaveformFunction(got: String?)
        case InvalidSort(got: String?)
        case InvalidWaveform(reason: String)
        case InvalidTurbulance(reason: String)
        case InvalidTextureCoordinateMod(reason: String)
        case InvalidStage(reason: String)
        case InvalidShader(reason: String)
        case UnknownToken(String)
        case EndOfData
    }

    let scanner: NSScanner

    init(shaders: String) {
        scanner = NSScanner(string: shaders)
    }

    func parse() throws {

    }

    private func readString() throws -> String {
        guard let str = scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) else {
            throw Q3ShaderParserError.EndOfData
        }
        
        return str
    }
    
    private func skipLine() {
        scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet())!
    }
    
    private func skipBlockComment() {
        while true {
            let token = try! readString()
            if token.hasSuffix("*/") {
                return
            }
        }
    }

    private func readSourceBlendMode(sourceBlendMode: String) throws -> SourceBlendMode {
        switch sourceBlendMode as String {
        case "GL_ONE": return .One
        case "GL_ZERO": return .Zero
        case "GL_DST_COLOR": return .DestColor
        case "GL_ONE_MINUS_DST_COLOR": return .OneMinusDestColor
        case "GL_SRC_ALPHA": return .SourceAlpha
        case "GL_ONE_MINUS_SRC_ALPHA": return .OneMinusSourceAlpha
        default: throw Q3ShaderParserError.UnknownToken(sourceBlendMode)
        }
    }

    private func readDestBlendMode(destBlendMode: String) throws -> DestBlendMode {
        switch destBlendMode as String {
        case "GL_ONE": return .One
        case "GL_ZERO": return .Zero
        case "GL_SRC_COLOR": return .SourceColor
        case "GL_ONE_MINUS_SRC_COLOR": return .OneMinusSourceColor
        case "GL_SRC_ALPHA": return .SourceAlpha
        case "GL_ONE_MINUS_SRC_ALPHA": return .OneMinusSourceAlpha
        default: throw Q3ShaderParserError.UnknownToken(destBlendMode)
        }
    }

    private func readWaveformFunction() throws -> WaveformFunction {
        let waveformFunction = try! readString()

        switch waveformFunction {
        case "sin": return .Sin
        case "triangle": return .Triangle
        case "square": return .Square
        case "sawtooth": return .Sawtooth
        case "inversesawtooth": return .InverseSawtooth
        default: throw Q3ShaderParserError.UnknownToken(waveformFunction)
        }
    }

    private func readWaveform() throws -> Waveform {
        let waveformFunction = try readWaveformFunction()

        guard let base = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let amplitude = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let phase = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let frequency = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        return Waveform(
            function: waveformFunction,
            base: base,
            amplitude: amplitude,
            phase: phase,
            frequency: frequency
        )
    }

    private func readSort() throws -> Sort {
        let sort = try! readString()

        switch sort {
        case "portal": return .Portal
        case "sky": return .Sky
        case "opaque": return .Opaque
        case "decal": return .Decal
        case "seeThrough": return .SeeThrough
        case "banner": return .Banner
        case "additive": return .Additive
        case "nearest": return .Nearest
        case "underwater": return .Underwater
        default: break
        }

        // Could be a manually specified sort order. Error out for now.
        let explicit = (sort as NSString).intValue
        throw Q3ShaderParserError.InvalidSort(got: "Manual sort: \(explicit)")
    }

    private func readTurbulance() throws -> TurbulanceDescription {
        guard let base = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let amplitude = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let phase = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        guard let frequency = scanner.scanFloat() else {
            throw Q3ShaderParserError.EndOfData
        }

        return TurbulanceDescription(
            base: base,
            amplitude: amplitude,
            phase: phase,
            frequency: frequency
        )
    }
    
    private func readTextureCoordinateMod() throws -> TextureCoordinateMod {
        let type = try! readString()
        
        switch type {
        case "turb":
            return .Turbulance(try readTurbulance())
            
        case "scale":
            guard let x = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "scale x")
            }
            
            guard let y = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "scale y")
            }
            
            return .Scale(x: x, y: y)
            
        case "scroll":
            guard let x = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "scroll x")
            }
            
            guard let y = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "scroll y")
            }
            
            return .Scroll(x: x, y: y)
            
        case "stretch":
            return .Stretch(try readWaveform())
        
        case "rotate":
            guard let degrees = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "rotate degrees")
            }
            
            return .Rotate(degrees: degrees)
            
            
        case "transform":
            guard let m00 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform m00")
            }
            
            guard let m01 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform m01")
            }
            
            guard let m10 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform m10")
            }
            
            guard let m11 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform m11")
            }
            
            guard let t0 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform t0")
            }
            
            guard let t1 = scanner.scanFloat() else {
                throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "transform t1")
            }
            
            return .Transform(m00: m00, m01: m01, m10: m10, m11: m11, t0: t0, t1: t1)
            
        default: throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "Invalid Type: \(type)")
        }
    }
    
    func readStage() throws -> Q3ShaderStage {
        var stage = Q3ShaderStage()
        
        var token = try! readString()
        
        while true {
            print("got token: \(token)")
            
            // Skip commented lines
            if token.hasPrefix("//") {
                scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet())
                continue
            } else if token.hasPrefix("/*") {
                skipBlockComment()
                continue
            }
            
            switch token.lowercaseString {
            case "map": stage.map = try! readString()
            
            case "clampmap":
                let clampmap = try! readString()
                print("clampmap: \(clampmap)")
                
            case "animmap":
                stage.map = "anim"
                
                guard let frequency = scanner.scanFloat() else {
                    throw Q3ShaderParserError.InvalidStage(reason: "animmap freq")
                }
                
                stage.animationFrequency = frequency
                
                // Read each animation map
                while true {
                    let map = try! readString()
                    
                    if !map.hasSuffix(".tga") {
                        token = map
                        break
                    }
                    
                    stage.animationMaps.append(map)
                }
                
                // We read the next token above when trying to get all of the
                // animation maps, so it's safe to continue
                continue
            
            case "alphafunc":
                let alphaFunc = try! readString()
                
                switch alphaFunc {
                case "GT0": stage.alphaFunction = .GT0
                case "LT128": stage.alphaFunction = .LT128
                case "GE128": stage.alphaFunction = .GE128
                default: throw Q3ShaderParserError.InvalidStage(reason: "invalid alphafunc: \(alphaFunc)")
                }
                
            case "depthfunc":
                let depthFunc = try! readString()
                
                switch depthFunc {
                case "lequal": stage.depthFunction = .LessThanOrEqual
                case "equal": stage.depthFunction = .Equal
                default: throw Q3ShaderParserError.InvalidStage(reason: "invalid depthFunc: \(depthFunc)")
                }
            
            case "blendfunc":
                let blendfunc = try! readString()
                
                switch blendfunc {
                case "add":
                    stage.blendSource = .One
                    stage.blendDest = .One
                case "filter":
                    stage.blendSource = .DestColor
                    stage.blendDest = .Zero
                case "blend":
                    stage.blendSource = .SourceAlpha
                    stage.blendDest = .OneMinusSourceAlpha
                default:
                    stage.blendSource = try readSourceBlendMode(blendfunc)
                    
                    let destBlend = try! readString()
                    
                    stage.blendDest = try readDestBlendMode(destBlend)
                }
            
            case "rgbgen":
                let gen = try! readString()
                
                switch gen {
                case "identity": stage.rgbGenerator = .Identity
                case "identityLighting": stage.rgbGenerator = .IdentityLighting
                case "wave": stage.rgbGenerator = .Wave(try readWaveform())
                case "vertex": stage.rgbGenerator = .Vertex
                case "lightingDiffuse": stage.rgbGenerator = .LightingDiffuse
                default:
                    throw Q3ShaderParserError.InvalidStage(reason: "Unknown rgbgen \(gen)")
                }
                
            case "alphagen":
                let gen = try! readString()
                
                switch gen {
                
                default:
                    throw Q3ShaderParserError.InvalidStage(reason: "Unknown alphagen \(gen)")
                }
                
            case "tcgen", "texgen":
                let gen = try! readString()
                
                switch gen {
                case "texture", "base": stage.textureCoordinateGenerator = .Base
                
                case "environment": stage.textureCoordinateGenerator = .Environment
                
                case "lightmap": stage.textureCoordinateGenerator = .Lightmap
                
                case "vector":
                    guard let sx = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    guard let sy = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    guard let sz = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    guard let tx = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    guard let ty = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    guard let tz = scanner.scanFloat() else {
                        throw Q3ShaderParserError.InvalidTextureCoordinateMod(reason: "texgen vector sx")
                    }
                    
                    stage.textureCoordinateGenerator = .Vector(sx: sx, sy: sy, sz: sz, tx: tx, ty: ty, tz: tz)
                    
                default:
                    throw Q3ShaderParserError.InvalidStage(reason: "Unknown texgen \(gen)")
                }
            
            case "tcmod": stage.textureCoordinateMods.append(try readTextureCoordinateMod())
            
            case "depthwrite": stage.depthWrite = true
            
            case "}": return stage
            
            default:
                throw Q3ShaderParserError.InvalidStage(reason: "Unknown token \(token)")
            }
            
            token = try! readString()
        }
    }
    
    private func readShader(name: String) throws -> Q3Shader {
        var shader = Q3Shader()
        shader.name = name
        
        while true {
            let token = try! readString()
            print("got token: \(token)")
            
            // Skip commented lines, radiant editor, q3map
            if token.hasPrefix("//") ||
                token.lowercaseString.hasPrefix("qer") ||
                token.lowercaseString.hasPrefix("q3map_") {
                skipLine()
                continue
            } else if token.hasPrefix("/*") {
                skipBlockComment()
                continue
            }
            
            switch token.lowercaseString {
            case "{": shader.stages.append(try! readStage())
            
            case "tesssize", "surfaceparm", "light": skipLine()
            
            case "skyparms": skipLine()
            
            case "cull": skipLine()
                
            case "deformvertexes": skipLine()
            
            case "fogparms": skipLine()
            
            case "nopicmip": skipLine()
            
            case "nomipmap": skipLine()
            
            case "polygonoffset": skipLine()
            
            case "portal": skipLine()
                
            case "sort": shader.sort = try! readSort()
                
            case "}": return shader
                
            default: throw Q3ShaderParserError.InvalidShader(reason: "Unknown token: \(token)")
            }
        }
    }
    
    func readShaders() throws -> Array<Q3Shader> {
        var shaders: Array<Q3Shader> = []
        
        while true {
            let name = try! readString()
            
            // Skip commented lines
            if name.hasPrefix("//") {
                scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet())
                continue
            }
            
            let brace = try! readString()
            
            if brace != "{" {
                throw Q3ShaderParserError.InvalidShader(reason: "No opening brace")
            }

            shaders.append(try readShader(name))
            
            if scanner.atEnd {
                break
            }
        }
        
        return shaders
    }
}
