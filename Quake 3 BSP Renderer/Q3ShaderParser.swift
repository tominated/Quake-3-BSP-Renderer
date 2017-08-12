//
//  Q3ShaderParser.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import Metal

class Q3ShaderParser {
    enum Q3ShaderParserError: Error {
        case invalidShader(reason: String)
        case unknownToken(String)
        case invalidFloat
        case invalidInt
        case endOfData
    }

    let scanner: Scanner

    init(shaderFile: String) {
        let lineComments = try! NSRegularExpression(pattern: "//(.*?)\r?\n", options: [.caseInsensitive, .dotMatchesLineSeparators])
        
        let length = shaderFile.lengthOfBytes(using: String.Encoding.ascii)
        
        let stripped = lineComments.stringByReplacingMatches(in: shaderFile, options: [], range: NSMakeRange(0, length), withTemplate: "\n")
        scanner = Scanner(string: stripped)
    }

    fileprivate func readString() throws -> String {
        var str: NSString?
        guard scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines, into: &str) else {
            throw Q3ShaderParserError.endOfData
        }

        return str! as String
    }

    fileprivate func readFloat() throws -> Float {
        var n: Float = 0
        guard scanner.scanFloat(&n) else {
            throw Q3ShaderParserError.invalidFloat
        }
        return n
    }
    
    fileprivate func readInt() throws -> Int32 {
        var n: Int32 = 0
        guard scanner.scanInt32(&n) else {
            throw Q3ShaderParserError.invalidInt
        }
        
        return n
    }
    
    fileprivate func skipLine() {
        scanner.scanUpToCharacters(from: CharacterSet.newlines, into: nil)
    }
    
    fileprivate func readBlendMode(_ blendMode: String) throws -> MTLBlendFactor {
        switch blendMode.uppercased() {
        case "GL_ONE": return .one
        case "GL_ZERO": return .zero
        case "GL_SRC_COLOR": return .sourceColor
        case "GL_SRC_ALPHA": return .sourceAlpha
        case "GL_DST_COLOR": return .destinationColor
        case "GL_DST_ALPHA": return .destinationAlpha
        case "GL_ONE_MINUS_SRC_COLOR": return .oneMinusSourceColor
        case "GL_ONE_MINUS_SRC_ALPHA": return .oneMinusSourceAlpha
        case "GL_ONE_MINUS_DST_COLOR": return .oneMinusDestinationColor
        case "GL_ONE_MINUS_DST_ALPHA": return .oneMinusDestinationAlpha
        case "GL_SRC_ALPHA_SATURATE": return .sourceAlphaSaturated
        default: throw Q3ShaderParserError.unknownToken(blendMode)
        }
    }

    fileprivate func readWaveformFunction() throws -> WaveformFunction {
        let waveformFunction = try readString()

        switch waveformFunction.lowercased() {
        case "sin": return .sin
        case "triangle": return .triangle
        case "square": return .square
        case "sawtooth": return .sawtooth
        case "inversesawtooth": return .inverseSawtooth
        case "noise": return .noise
        default: throw Q3ShaderParserError.unknownToken(waveformFunction)
        }
    }

    fileprivate func readWaveform() throws -> Waveform {
        let waveformFunction = try readWaveformFunction()
        let base = try readFloat()
        let amplitude = try readFloat()
        let phase = try readFloat()
        let frequency = try readFloat()

        return Waveform(
            function: waveformFunction,
            base: base,
            amplitude: amplitude,
            phase: phase,
            frequency: frequency
        )
    }

    fileprivate func readSort() throws -> Sort {
        let offset = scanner.scanLocation
        let sort = try readString()

        switch sort.lowercased() {
        case "portal": return .portal
        case "sky": return .sky
        case "opaque": return .opaque
        case "decal": return .decal
        case "seeThrough": return .seeThrough
        case "banner": return .banner
        case "additive": return .additive
        case "nearest": return .nearest
        case "underwater": return .underwater
        default: break
        }

        scanner.scanLocation = offset
        return .explicit(try readInt())
    }

    fileprivate func readTurbulance() throws -> TurbulanceDescription {
        // Potential waveform func as first param
        let token = try readString()
        let base = try Float(token) ?? readFloat()

        let amplitude = try readFloat()
        let phase = try readFloat()
        let frequency = try readFloat()

        return TurbulanceDescription(
            base: base,
            amplitude: amplitude,
            phase: phase,
            frequency: frequency
        )
    }
    
    fileprivate func readTextureCoordinateMod() throws -> TextureCoordinateMod {
        let type = try readString()
        
        switch type.lowercased() {
        case "turb":
            return .turbulance(try readTurbulance())
            
        case "scale":
            let x = try readFloat()
            let y = try readFloat()
            
            return .scale(x: x, y: y)
            
        case "scroll":
            let x = try readFloat()
            let y = try readFloat()
            
            return .scroll(x: x, y: y)
            
        case "stretch":
            return .stretch(try readWaveform())
        
        case "rotate":
            let degrees = try readFloat()
            
            // For some reason there's some shaders that have a second param...
            let offset = scanner.scanLocation
            if (try? readFloat()) == nil {
                scanner.scanLocation = offset
            }
            
            return .rotate(degrees: degrees)
            
            
        case "transform":
            let m00 = try readFloat()
            let m01 = try readFloat()
            let m10 = try readFloat()
            let m11 = try readFloat()
            let t0 = try readFloat()
            let t1 = try readFloat()
            
            return .transform(m00: m00, m01: m01, m10: m10, m11: m11, t0: t0, t1: t1)
            
        default: throw Q3ShaderParserError.unknownToken(type)
        }
    }
    
    func readMap() throws -> StageTexture {
        let token = try readString()
        
        switch token.lowercased() {
        case "$whiteimage": return .white
        case "$lightmap": return .lightmap
        default: return .texture(token)
        }
    }
    
    func readStage() throws -> Q3ShaderStage {
        var stage = Q3ShaderStage()
        var depthWriteOverride = false
        
        var token = try readString()
        
        while true {
            switch token.lowercased() {
            case "map":
                stage.map = try readMap()
                if case .lightmap = stage.map {
                    stage.textureCoordinateGenerator = .lightmap
                }
            
            case "clampmap": stage.map = .textureClamp(try readString())
                
            case "animmap":
                let freq = try readFloat()
                var maps: Array<String> = []
                
                // Read each animation map
                while true {
                    let map = try readString()
                    
                    if !map.hasSuffix(".tga") {
                        token = map
                        break
                    }
                    
                    maps.append(map)
                }
                
                stage.map = .animated(frequency: freq, maps)
                
                // We read the next token above when trying to get all of the
                // animation maps, so it's safe to continue
                continue
            
            case "alphafunc":
                let alphaFunc = try readString()
                
                switch alphaFunc {
                case "GT0": stage.alphaFunction = .gt0
                case "LT128": stage.alphaFunction = .lt128
                case "GE128": stage.alphaFunction = .ge128
                default: throw Q3ShaderParserError.unknownToken(alphaFunc)
                }
                
            case "depthfunc":
                let depthFunc = try readString()
                
                switch depthFunc {
                case "lequal": stage.depthFunction = .lessEqual
                case "equal": stage.depthFunction = .equal
                default: throw Q3ShaderParserError.unknownToken(depthFunc)
                }
            
            case "blendfunc":
                let blendfunc = try readString()
                
                if !depthWriteOverride {
                    stage.depthWrite = false
                }
                
                switch blendfunc.lowercased() {
                case "add", "gl_add":
                    stage.blending = (.one, .one)
                case "filter":
                    stage.blending = (.destinationColor, .zero)
                case "blend":
                    stage.blending = (.sourceAlpha, .oneMinusSourceAlpha)
                default:
                    let blendSource = try readBlendMode(blendfunc)
                    let blendDestination = try readBlendMode(try readString())
                    stage.blending = (blendSource, blendDestination)
                }
            
            case "rgbgen":
                let gen = try readString()
                
                switch gen.lowercased() {
                case "identity": stage.rgbGenerator = .identity
                case "identitylighting": stage.rgbGenerator = .identityLighting
                case "wave": stage.rgbGenerator = .wave(try readWaveform())
                case "vertex": stage.rgbGenerator = .vertex
                case "lightingdiffuse": stage.rgbGenerator = .lightingDiffuse
                case "entity": stage.rgbGenerator = .entity
                case "oneminusentity": stage.rgbGenerator = .oneMinusEntity
                case "exactvertex": stage.rgbGenerator = .exactVertex
                default: throw Q3ShaderParserError.unknownToken(gen)
                }
                
            case "alphagen":
                let gen = try readString()
                
                switch gen.lowercased() {
                case "wave": stage.alphaGenerator = .wave(try readWaveform())
                case "const": stage.alphaGenerator = .constant(try readFloat())
                case "identity": stage.alphaGenerator = .identity
                case "entity": stage.alphaGenerator = .entity
                case "oneminusentity": stage.alphaGenerator = .oneMinusEntity
                case "vertex": stage.alphaGenerator = .vertex
                case "lightingspecular": stage.alphaGenerator = .lightingSpecular
                case "oneminusvertex": stage.alphaGenerator = .oneMinusVertex
                case "portal": stage.alphaGenerator = .portal(try readFloat())
                default: throw Q3ShaderParserError.unknownToken(gen)
                }
                
            case "tcgen", "texgen":
                let gen = try readString()
                
                switch gen.lowercased() {
                case "texture", "base": stage.textureCoordinateGenerator = .base
                
                case "environment": stage.textureCoordinateGenerator = .environment
                
                case "lightmap": stage.textureCoordinateGenerator = .lightmap
                
                case "vector":
                    let sx = try readFloat()
                    let sy = try readFloat()
                    let sz = try readFloat()
                    let tx = try readFloat()
                    let ty = try readFloat()
                    let tz = try readFloat()
                    
                    stage.textureCoordinateGenerator = .vector(sx: sx, sy: sy, sz: sz, tx: tx, ty: ty, tz: tz)
                    
                default: throw Q3ShaderParserError.unknownToken(gen)
                }
            
            case "tcmod": stage.textureCoordinateMods.append(try readTextureCoordinateMod())
            
            case "depthwrite":
                depthWriteOverride = true
                stage.depthWrite = true
            
            case "detail": break
            
            case "}": return stage
            
            default:
                throw Q3ShaderParserError.unknownToken(token)
            }
            
            token = try readString()
        }
    }
    
    fileprivate func readSkyParams() throws -> SkyParams {
        var sky = SkyParams()
        
        let farBox = try readString()
        if farBox != "-" {
            sky.farBox = farBox
        }
        
        let cloudHeight = try readString()
        if cloudHeight != "-" {
            sky.cloudHeight = NSString(string: cloudHeight).floatValue
        }
        
        let nearBox = try readString()
        if nearBox != "-" {
            sky.nearBox = nearBox
        }
        
        return sky
    }
    
    fileprivate func readCull() throws -> MTLCullMode {
        let token = try readString()
        
        switch token.lowercased() {
        case "front": return .front
        case "none", "twosided", "disable": return .none
        case "back", "backside", "backsided": return .back
        default: throw Q3ShaderParserError.unknownToken(token)
        }
    }
    
    fileprivate func readVertexDeform() throws -> VertexDeform {
        let token = try readString()
        
        if token.lowercased().hasPrefix("text") {
            return .text
        }
        
        switch token.lowercased() {
        case "autosprite": return .autoSprite
        case "autosprite2": return .autoSprite2
        case "projectionshadow": return .projectionShadow
        
        case "bulge":
            let width = try readFloat()
            let height = try readFloat()
            let speed = try readFloat()
            return .bulge(width: width, height: height, speed: speed)
        
        case "wave":
            let spread = try readFloat()
            let wave = try readWaveform()
            return .wave(spread: spread, waveform: wave)
        
        case "normal":
            let freq = try readFloat()
            let amp = try readFloat()
            return .normal(frequency: freq, amplitude: amp)
        
        case "move":
            let x = try readFloat()
            let y = try readFloat()
            let z = try readFloat()
            let wave = try readWaveform()
            return .move(x: x, y: y, z: z, waveform: wave)
        
        default: throw Q3ShaderParserError.unknownToken(token)
        }
    }
    
    fileprivate func readShader(_ name: String) throws -> Q3Shader {
        var shader = Q3Shader()
        shader.name = name
        
        while true {
            let token = try readString()
            
            switch token.lowercased() {
            case "{": shader.stages.append(try readStage())
            
            case "skyparms": shader.sky = try readSkyParams()
            
            case "cull": shader.cull = try readCull()
            
            case "deformvertexes": shader.vertexDeforms.append(try readVertexDeform())
            
            case "portal": shader.sort = .portal
                
            case "sort": shader.sort = try readSort()
            
            case "nomipmap", "nomipmaps": shader.mipmapsEnabled = false
                
            case "}": return shader
                
            // Can ignore these safely
            case
                "nopicmip", "polygonoffset", "light1", "entitymergable",
                "qer_nocarve", "q3map_globaltexture","lightning":
                break
            
            case
                "q3map_backshader", "q3map_sun", "q3map_surfacelight",
                "q3map_lightimage", "q3map_lightsubdivide", "qer_editorimage",
                "q3map_backsplash", "qer_trans", "q3map_flare", "sky",
                "cloudparms", "tesssize", "surfaceparm", "light", "fogparms":
                skipLine()
                
            default: throw Q3ShaderParserError.unknownToken(token)
            }
        }
    }
    
    func readShaders() throws -> Array<Q3Shader> {
        var shaders: Array<Q3Shader> = []
        
        while true {
            let name = try readString()
            let brace = try readString()
            
            if brace != "{" {
                throw Q3ShaderParserError.invalidShader(reason: "No opening brace")
            }

            shaders.append(try readShader(name))
            
            if scanner.isAtEnd {
                break
            }
        }
        
        return shaders
    }
}
