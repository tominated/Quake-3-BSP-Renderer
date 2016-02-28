//
//  Q3TextureLoader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 27/02/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import MetalKit

class Q3TextureLoader {
    let loader: Q3ResourceLoader
    let device: MTLDevice
    
    private let commandQueue: MTLCommandQueue
    private let textureLoader: MTKTextureLoader
    private var whiteTexture: MTLTexture? = nil
    private var textureCache: Dictionary<String, MTLTexture> = Dictionary()
    
    private let lightmapDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
        .RGBA8Unorm,
        width: 128,
        height: 128,
        mipmapped: true
    )
    
    init(loader: Q3ResourceLoader, device: MTLDevice) {
        self.loader = loader
        self.device = device
        commandQueue = device.newCommandQueue()
        textureLoader = MTKTextureLoader(device: device)
    }
    
    func loadTexture(path: String) -> MTLTexture? {
        if let texture = textureCache[path] {
            print("Loaded texture '\(path)' from cache")
            return texture
        }
        
        guard let image = loader.loadTexture(path) else {
            print("Error loading texture '\(path)'")
            return nil
        }
        
        let texture =  try! textureLoader.newTextureWithCGImage(
            image.CGImage!,
            options: [MTKTextureLoaderOptionAllocateMipmaps: 1]
        )
        
        generateMipmaps(texture)
        
        textureCache[path] = texture
        
        print("Loaded texture '\(path)'")
        
        return texture
    }
    
    func loadWhiteTexture() -> MTLTexture {
        if let whiteTexture = self.whiteTexture {
            return whiteTexture
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            .RGBA8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        
        let whiteTexture = device.newTextureWithDescriptor(descriptor)
        whiteTexture.replaceRegion(
            MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [UInt8(255), UInt8(255), UInt8(255), UInt8(255)],
            bytesPerRow: 4 * sizeof(UInt8)
        )
        
        self.whiteTexture = whiteTexture
        
        return whiteTexture
    }
    
    func loadLightmap(lightmap: Q3Lightmap) -> MTLTexture {
        let texture = device.newTextureWithDescriptor(lightmapDescriptor)
        
        texture.replaceRegion(
            MTLRegionMake2D(0, 0, 128, 128),
            mipmapLevel: 0,
            withBytes: lightmap,
            bytesPerRow: 128 * 4 * sizeof(UInt8)
        )
        
        generateMipmaps(texture)
        
        return texture
    }
    
    func loadAllShaderTextures(shaders: Array<Q3Shader>) -> Dictionary<String, MTLTexture> {
        var textures: Dictionary<String, MTLTexture> = Dictionary()
        
        for shader in shaders {
            for stage in shader.stages {
                switch stage.map {
                case .Texture(let name):
                    if textures[name] != nil { continue }
                    textures[name] = loadTexture(name) ?? loadWhiteTexture()

                case .TextureClamp(let name):
                    if textures[name] != nil { continue }
                    textures[name] = loadTexture(name) ?? loadWhiteTexture()
                
                case .Animated(frequency: _, let names):
                    for name in names {
                        if textures[name] != nil { continue }
                        textures[name] = loadTexture(name) ?? loadWhiteTexture()
                    }
                    
                default: break
                }
            }
        }
        
        return textures
    }
    
    private func generateMipmaps(texture: MTLTexture) {
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.blitCommandEncoder()
        
        commandEncoder.generateMipmapsForTexture(texture)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
    }
}