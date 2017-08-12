//
//  Targa.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 14/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import UIKit

/*
func imageFromTGAData(_ data: Data) -> UIImage? {
    (data as NSData).bytes
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
    
    let finalData = Data(bytes: UnsafePointer<UInt8>(imageData), count: imageDataLength)
    
    return imageFromRGBAData(finalData, width: width, height: height)
}
    
private func imageFromRGBAData(_ data: Data, width: Int, height: Int) -> UIImage? {
    let pixelData = (data as NSData).bytes
    let bytesPerPixel = 4
    let scanWidth = bytesPerPixel * width
    
    let provider = CGDataProvider(dataInfo: nil, data: pixelData, size: height * scanWidth, releaseData: nil)
    
    let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.last.rawValue)
    let renderingIntent: CGColorRenderingIntent = .defaultIntent
    
    let imageRef = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8, // bitsPerComponent
        bitsPerPixel: 32, // bitsPerPixel
        bytesPerRow: scanWidth, // bytesPerRow
        space: colorSpaceRef, // colorspace
        bitmapInfo: bitmapInfo, // bitmapInfo
        provider: provider, // provider
        decode: nil, // decode
        shouldInterpolate: false, // shouldInterpolate
        intent: renderingIntent // intent
    )
    
    if let ref = imageRef {
        return UIImage(cgImage: ref)
    }
    
    return nil
}
*/
