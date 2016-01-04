//
//  BinaryReader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import Foundation

class BinaryReader {
    var position: Int
    var data: NSData
    
    init(data: NSData) {
        position = 0
        self.data = data
    }
    
    func reset() {
        position = 0
    }
    
    func jump(addr: Int) {
        position = addr
    }
    
    func skip(length: Int) {
        position += length
    }
    
    func getInt8() -> Int8 {
        var i: Int8 = 0
        data.getBytes(&i, range: NSMakeRange(position, sizeofValue(i)))
        position += sizeofValue(i)
        return i
    }
    
    func getUInt8() -> UInt8 {
        var i: UInt8 = 0
        data.getBytes(&i, range: NSMakeRange(position, sizeofValue(i)))
        position += sizeofValue(i)
        return i
    }
    
    func getInt32() -> Int32 {
        var i: Int32 = 0
        data.getBytes(&i, range: NSMakeRange(position, sizeofValue(i)))
        position += sizeofValue(i)
        return i
    }

    func getUInt32() -> UInt32 {
        var i: UInt32 = 0
        data.getBytes(&i, range: NSMakeRange(position, sizeofValue(i)))
        position += sizeofValue(i)
        return i
    }
    
    func getFloat32() -> Float32 {
        var f: Float32 = 0
        data.getBytes(&f, range: NSMakeRange(position, sizeofValue(f)))
        position += sizeofValue(f)
        return f
    }
    
    func getASCII(length: Int) -> NSString? {
        let strData = data.subdataWithRange(NSMakeRange(position, length))
        position += length
        return NSString(bytes: strData.bytes, length: length, encoding: NSASCIIStringEncoding)
    }
    
    func getASCIIUntilNull(max: Int, skipAhead: Bool = true) -> String {
        var chars: [CChar] = []
        var iterations = 0
        
        while true {
            let char = getInt8()
            chars.append(char)
            iterations += 1
            
            if char == 0 || iterations >= max {
                break
            }
        }
        
        if skipAhead {
            position += max
        } else {
            position += iterations
        }
        
        return chars.withUnsafeBufferPointer({ buffer in
            return String.fromCString(buffer.baseAddress)!
        })
    }
}