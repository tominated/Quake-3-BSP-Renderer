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
        guard let image = loader.loadTexture(path) else {
            return nil
        }
        
        let texture =  try! textureLoader.newTextureWithCGImage(image.CGImage!, options: [
            MTKTextureLoaderOptionAllocateMipmaps: 1
        ])
        
        generateMipmaps(texture)
        
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
    
    private func generateMipmaps(texture: MTLTexture) {
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.blitCommandEncoder()
        
        commandEncoder.generateMipmapsForTexture(texture)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
    }
}