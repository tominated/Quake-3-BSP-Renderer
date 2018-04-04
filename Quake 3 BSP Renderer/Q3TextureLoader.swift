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
    
    fileprivate let commandQueue: MTLCommandQueue
    fileprivate let textureLoader: MTKTextureLoader
    fileprivate var whiteTexture: MTLTexture? = nil
    fileprivate var textureCache: Dictionary<String, MTLTexture> = Dictionary()
    
    fileprivate let lightmapDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: 128,
        height: 128,
        mipmapped: true
    )
    
    init(loader: Q3ResourceLoader, device: MTLDevice) {
        self.loader = loader
        self.device = device
        commandQueue = device.makeCommandQueue()!
        textureLoader = MTKTextureLoader(device: device)
    }
    
    func loadTexture(_ path: String) -> MTLTexture? {
        if let texture = textureCache[path] {
            print("Loaded texture '\(path)' from cache")
            return texture
        }
        
        guard let image = loader.loadTexture(path) else {
            print("Error loading texture '\(path)'")
            return nil
        }
        
        let texture =  try! textureLoader.newTexture(
            cgImage: image.cgImage!,
            options: [MTKTextureLoader.Option.allocateMipmaps: 1 as NSObject]
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
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        
        let whiteTexture = device.makeTexture(descriptor: descriptor)
        whiteTexture?.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [UInt8(255), UInt8(255), UInt8(255), UInt8(255)],
            bytesPerRow: 4 * MemoryLayout<UInt8>.size
        )
        
        self.whiteTexture = whiteTexture
        
        return whiteTexture!
    }
    
    func loadLightmap(_ lightmap: Q3Lightmap) -> MTLTexture {
        let texture = device.makeTexture(descriptor: lightmapDescriptor)
        
        texture?.replace(
            region: MTLRegionMake2D(0, 0, 128, 128),
            mipmapLevel: 0,
            withBytes: lightmap,
            bytesPerRow: 128 * 4
        )
        
        generateMipmaps(texture!)
        
        return texture!
    }
    
    fileprivate func generateMipmaps(_ texture: MTLTexture) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeBlitCommandEncoder()
        
        commandEncoder?.generateMipmaps(for: texture)
        
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
}
