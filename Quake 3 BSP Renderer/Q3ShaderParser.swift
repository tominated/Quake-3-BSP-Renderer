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
    enum Q3ShaderParserError: ErrorType {
        case InvalidShader(reason: String)
        case UnknownToken(String)
        case InvalidFloat
        case InvalidInt
        case EndOfData
    }

    let scanner: NSScanner

    init(shaderFile: String) {
        let lineComments = try! NSRegularExpression(pattern: "//(.*?)\r?\n", options: [.CaseInsensitive, .DotMatchesLineSeparators])
        
        let length = shaderFile.lengthOfBytesUsingEncoding(NSASCIIStringEncoding)
        
        let stripped = lineComments.stringByReplacingMatchesInString(shaderFile, options: [], range: NSMakeRange(0, length), withTemplate: "\n")
        scanner = NSScanner(string: stripped)
    }

    private func readString() throws -> String {
        guard let str = scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) else {
            throw Q3ShaderParserError.EndOfData
        }
        
        return str
    }
    
    private func readFloat() throws -> Float {
        guard let n = scanner.scanFloat() else {
            throw Q3ShaderParserError.InvalidFloat
        }
        
        return n
    }
    
    private func readInt() throws -> Int32 {
        guard let n = scanner.scanInt() else {
            throw Q3ShaderParserError.InvalidInt
        }
        
        return n
    }
    
    private func skipLine() {
        scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet())!
    }
    
    private func readBlendMode(blendMode: String) throws -> MTLBlendFactor {
        switch blendMode.uppercaseString {
        case "GL_ONE": return .One
        case "GL_ZERO": return .Zero
        case "GL_SRC_COLOR": return .SourceColor
        case "GL_SRC_ALPHA": return .SourceAlpha
        case "GL_DST_COLOR": return .DestinationColor
        case "GL_DST_ALPHA": return .DestinationAlpha
        case "GL_ONE_MINUS_SRC_COLOR": return .OneMinusSourceColor
        case "GL_ONE_MINUS_SRC_ALPHA": return .OneMinusSourceAlpha
        case "GL_ONE_MINUS_DST_COLOR": return .OneMinusDestinationColor
        case "GL_ONE_MINUS_DST_ALPHA": return .OneMinusDestinationAlpha
        case "GL_SRC_ALPHA_SATURATE": return .SourceAlphaSaturated
        default: throw Q3ShaderParserError.UnknownToken(blendMode)
        }
    }

    private func readWaveformFunction() throws -> WaveformFunction {
        let waveformFunction = try readString()

        switch waveformFunction.lowercaseString {
        case "sin": return .Sin
        case "triangle": return .Triangle
        case "square": return .Square
        case "sawtooth": return .Sawtooth
        case "inversesawtooth": return .InverseSawtooth
        case "noise": return .Noise
        default: throw Q3ShaderParserError.UnknownToken(waveformFunction)
        }
    }

    private func readWaveform() throws -> Waveform {
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

    private func readSort() throws -> Sort {
        let offset = scanner.scanLocation
        let sort = try readString()

        switch sort.lowercaseString {
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

        scanner.scanLocation = offset
        return .Explicit(try readInt())
    }

    private func readTurbulance() throws -> TurbulanceDescription {
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
    
    private func readTextureCoordinateMod() throws -> TextureCoordinateMod {
        let type = try readString()
        
        switch type.lowercaseString {
        case "turb":
            return .Turbulance(try readTurbulance())
            
        case "scale":
            let x = try readFloat()
            let y = try readFloat()
            
            return .Scale(x: x, y: y)
            
        case "scroll":
            let x = try readFloat()
            let y = try readFloat()
            
            return .Scroll(x: x, y: y)
            
        case "stretch":
            return .Stretch(try readWaveform())
        
        case "rotate":
            let degrees = try readFloat()
            
            // For some reason there's some shaders that have a second param...
            let offset = scanner.scanLocation
            if (try? readFloat()) == nil {
                scanner.scanLocation = offset
            }
            
            return .Rotate(degrees: degrees)
            
            
        case "transform":
            let m00 = try readFloat()
            let m01 = try readFloat()
            let m10 = try readFloat()
            let m11 = try readFloat()
            let t0 = try readFloat()
            let t1 = try readFloat()
            
            return .Transform(m00: m00, m01: m01, m10: m10, m11: m11, t0: t0, t1: t1)
            
        default: throw Q3ShaderParserError.UnknownToken(type)
        }
    }
    
    func readMap() throws -> StageTexture {
        let token = try readString()
        
        switch token.lowercaseString {
        case "$whiteimage": return .White
        case "$lightmap": return .Lightmap
        default: return .Texture(token)
        }
    }
    
    func readStage() throws -> Q3ShaderStage {
        var stage = Q3ShaderStage()
        var depthWriteOverride = false
        
        var token = try readString()
        
        while true {
            switch token.lowercaseString {
            case "map": stage.map = try readMap()
            
            case "clampmap": stage.map = .TextureClamp(try readString())
                
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
                
                stage.map = .Animated(frequency: freq, maps)
                
                // We read the next token above when trying to get all of the
                // animation maps, so it's safe to continue
                continue
            
            case "alphafunc":
                let alphaFunc = try readString()
                
                switch alphaFunc {
                case "GT0": stage.alphaFunction = .GT0
                case "LT128": stage.alphaFunction = .LT128
                case "GE128": stage.alphaFunction = .GE128
                default: throw Q3ShaderParserError.UnknownToken(alphaFunc)
                }
                
            case "depthfunc":
                let depthFunc = try readString()
                
                switch depthFunc {
                case "lequal": stage.depthFunction = .LessEqual
                case "equal": stage.depthFunction = .Equal
                default: throw Q3ShaderParserError.UnknownToken(depthFunc)
                }
            
            case "blendfunc":
                let blendfunc = try readString()
                
                if !depthWriteOverride {
                    stage.depthWrite = false
                }
                
                switch blendfunc.lowercaseString {
                case "add", "gl_add":
                    stage.blending = (.One, .One)
                case "filter":
                    stage.blending = (.DestinationColor, .Zero)
                case "blend":
                    stage.blending = (.SourceAlpha, .OneMinusSourceAlpha)
                default:
                    let blendSource = try readBlendMode(blendfunc)
                    let blendDestination = try readBlendMode(try readString())
                    stage.blending = (blendSource, blendDestination)
                }
            
            case "rgbgen":
                let gen = try readString()
                
                switch gen.lowercaseString {
                case "identity": stage.rgbGenerator = .Identity
                case "identitylighting": stage.rgbGenerator = .IdentityLighting
                case "wave": stage.rgbGenerator = .Wave(try readWaveform())
                case "vertex": stage.rgbGenerator = .Vertex
                case "lightingdiffuse": stage.rgbGenerator = .LightingDiffuse
                case "entity": stage.rgbGenerator = .Entity
                case "oneminusentity": stage.rgbGenerator = .OneMinusEntity
                case "exactvertex": stage.rgbGenerator = .ExactVertex
                default: throw Q3ShaderParserError.UnknownToken(gen)
                }
                
            case "alphagen":
                let gen = try readString()
                
                switch gen.lowercaseString {
                case "wave": stage.alphaGenerator = .Wave(try readWaveform())
                case "const": stage.alphaGenerator = .Constant(try readFloat())
                case "identity": stage.alphaGenerator = .Identity
                case "entity": stage.alphaGenerator = .Entity
                case "oneminusentity": stage.alphaGenerator = .OneMinusEntity
                case "vertex": stage.alphaGenerator = .Vertex
                case "lightingspecular": stage.alphaGenerator = .LightingSpecular
                case "oneminusvertex": stage.alphaGenerator = .OneMinusVertex
                case "portal": stage.alphaGenerator = .Portal(try readFloat())
                default: throw Q3ShaderParserError.UnknownToken(gen)
                }
                
            case "tcgen", "texgen":
                let gen = try readString()
                
                switch gen.lowercaseString {
                case "texture", "base": stage.textureCoordinateGenerator = .Base
                
                case "environment": stage.textureCoordinateGenerator = .Environment
                
                case "lightmap": stage.textureCoordinateGenerator = .Lightmap
                
                case "vector":
                    let sx = try readFloat()
                    let sy = try readFloat()
                    let sz = try readFloat()
                    let tx = try readFloat()
                    let ty = try readFloat()
                    let tz = try readFloat()
                    
                    stage.textureCoordinateGenerator = .Vector(sx: sx, sy: sy, sz: sz, tx: tx, ty: ty, tz: tz)
                    
                default: throw Q3ShaderParserError.UnknownToken(gen)
                }
            
            case "tcmod": stage.textureCoordinateMods.append(try readTextureCoordinateMod())
            
            case "depthwrite":
                depthWriteOverride = true
                stage.depthWrite = true
            
            case "detail": break
            
            case "}": return stage
            
            default:
                throw Q3ShaderParserError.UnknownToken(token)
            }
            
            token = try readString()
        }
    }
    
    private func readSkyParams() throws -> SkyParams {
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
    
    private func readCull() throws -> MTLCullMode {
        let token = try readString()
        
        switch token.lowercaseString {
        case "front": return .Front
        case "none", "twosided", "disable": return .None
        case "back", "backside", "backsided": return .Back
        default: throw Q3ShaderParserError.UnknownToken(token)
        }
    }
    
    private func readVertexDeform() throws -> VertexDeform {
        let token = try readString()
        
        if token.lowercaseString.hasPrefix("text") {
            return .Text
        }
        
        switch token.lowercaseString {
        case "autosprite": return .AutoSprite
        case "autosprite2": return .AutoSprite2
        case "projectionshadow": return .ProjectionShadow
        
        case "bulge":
            let width = try readFloat()
            let height = try readFloat()
            let speed = try readFloat()
            return .Bulge(width: width, height: height, speed: speed)
        
        case "wave":
            let spread = try readFloat()
            let wave = try readWaveform()
            return .Wave(spread: spread, waveform: wave)
        
        case "normal":
            let freq = try readFloat()
            let amp = try readFloat()
            return .Normal(frequency: freq, amplitude: amp)
        
        case "move":
            let x = try readFloat()
            let y = try readFloat()
            let z = try readFloat()
            let wave = try readWaveform()
            return .Move(x: x, y: y, z: z, waveform: wave)
        
        default: throw Q3ShaderParserError.UnknownToken(token)
        }
    }
    
    private func readShader(name: String) throws -> Q3Shader {
        var shader = Q3Shader()
        shader.name = name
        
        while true {
            let token = try readString()
            
            switch token.lowercaseString {
            case "{": shader.stages.append(try readStage())
            
            case "skyparms": shader.sky = try readSkyParams()
            
            case "cull": shader.cull = try readCull()
            
            case "deformvertexes": shader.vertexDeforms.append(try readVertexDeform())
            
            case "portal": shader.sort = .Portal
                
            case "sort": shader.sort = try readSort()
                
            case "}": return shader
                
            // Can ignore these safely
            case "nopicmip", "nomipmap", "nomipmaps", "polygonoffset", "light1",
                "entitymergable", "qer_nocarve", "q3map_globaltexture",
                "lightning":
                break
            
            case
                "q3map_backshader", "q3map_sun", "q3map_surfacelight",
                "q3map_lightimage", "q3map_lightsubdivide", "qer_editorimage",
                "q3map_backsplash", "qer_trans", "q3map_flare", "sky",
                "cloudparms", "tesssize", "surfaceparm", "light", "fogparms":
                skipLine()
                
            default: throw Q3ShaderParserError.UnknownToken(token)
            }
        }
    }
    
    func readShaders() throws -> Array<Q3Shader> {
        var shaders: Array<Q3Shader> = []
        
        while true {
            let name = try readString()
            let brace = try readString()
            
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
