//
//  Targa.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 14/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import UIKit

func imageFromTGAData(data: NSData) -> UIImage? {
    data.bytes
    let buffer = BinaryReader(data: data)
    buffer.skip(2)
    
    let imageType = buffer.getUInt8()
    
    // Unsupported file type
    if (imageType != 2 && imageType != 3) {
        return nil
    }
    
    buffer.skip(9)
    
    let width = Int(buffer.getUInt16())
    let height = Int(buffer.getUInt16())
    let bitDepth = Int(buffer.getUInt8())
    
    let colorMode = bitDepth / 8
    let imageDataLength = width * height * 4
    
    var imageData: Array<UInt8> = []
    imageData.reserveCapacity(imageDataLength)
    
    buffer.skip(1)
    
    // Swap image data from BGR(A) to RGBA
    for _ in 0..<(width * height) {
        let b = buffer.getUInt8()
        let g = buffer.getUInt8()
        let r = buffer.getUInt8()
        let a = colorMode == 4 ? buffer.getUInt8() : 1
        
        imageData.append(r)
        imageData.append(g)
        imageData.append(b)
        imageData.append(a)
    }
    
    // Invert the Y axis
    let imageDataAsUInt32 = UnsafeMutablePointer<UInt32>(imageData)
    for y in 0..<(height / 2) {
        for x in 0..<width {
            let top = imageDataAsUInt32[y * width + x]
            let bottom = imageDataAsUInt32[(height - 1 - y) * width + x]
            imageDataAsUInt32[(height - 1 - y) * width + x] = top
            imageDataAsUInt32[y * width + x] = bottom
        }
    }
    
    let finalData = NSData(bytes: imageData, length: imageDataLength)
    
    return imageFromRGBAData(finalData, width: width, height: height)
}
    
private func imageFromRGBAData(data: NSData, width: Int, height: Int) -> UIImage? {
    let pixelData = data.bytes
    let bytesPerPixel = 4
    let scanWidth = bytesPerPixel * width
    
    let provider = CGDataProviderCreateWithData(nil, pixelData, height * scanWidth, nil)
    
    let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.Last.rawValue)
    let renderingIntent: CGColorRenderingIntent = .RenderingIntentDefault
    
    let imageRef = CGImageCreate(
        width,
        height,
        8, // bitsPerComponent
        32, // bitsPerPixel
        scanWidth, // bytesPerRow
        colorSpaceRef, // colorspace
        bitmapInfo, // bitmapInfo
        provider, // provider
        nil, // decode
        false, // shouldInterpolate
        renderingIntent // intent
    )
    
    if let ref = imageRef {
        return UIImage(CGImage: ref)
    }
    
    return nil
}