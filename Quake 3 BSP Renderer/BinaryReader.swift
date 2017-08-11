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
    var data: Data
    
    init(data: Data) {
        position = 0
        self.data = data
    }
    
    func reset() {
        position = 0
    }
    
    func jump(_ addr: Int) {
        position = addr
    }
    
    func skip(_ length: Int) {
        position += length
    }
    
    func getInt8() -> Int8 {
        return getNumber(0)
    }
    
    func getUInt8() -> UInt8 {
        return getNumber(0)
    }
    
    func getInt16() -> Int16 {
        return getNumber(0)
    }
    
    func getUInt16() -> UInt16 {
        return getNumber(0)
    }
    
    func getInt32() -> Int32 {
        return getNumber(0)
    }

    func getUInt32() -> UInt32 {
        return getNumber(0)
    }
    
    func getFloat32() -> Float32 {
        return getNumber(0)
    }
    
    func getASCIIUntilNull(_ max: Int, skipAhead: Bool = true) -> String {
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
            return String(cString: buffer.baseAddress!)
        })
    }
    
    fileprivate func getNumber<T>(_ zero: T) -> T {
        var x = zero
        (data as NSData).getBytes(&x, range: NSMakeRange(position, MemoryLayout<T>.size))
        position += MemoryLayout<T>.size
        return x
    }
}
