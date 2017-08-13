//
//  BinaryParser.swift
//  Quake3BSPParser
//
//  Created by Thomas Brunoli on 28/05/2017.
//  Copyright © 2017 Quake3BSPParser. All rights reserved.
//

import Foundation
import simd

internal class BinaryParser {
    let data: Data;
    var position: Int = 0;

    public init(_ data: Data) {
        self.data = data;
    }

    public func reset() {
        position = 0;
    }

    public func jump(to addr: Int) {
        position = addr;
    }

    public func skip(length: Int) {
        position += length;
    }

    public func getNumber<T>() -> T {
        let size = MemoryLayout<T>.size
        let sub = data.subdata(in: position ..< (position + size))
        let number = sub.withUnsafeBytes { (pointer: UnsafePointer<T>) -> T in
            return pointer.pointee;
        }

        position += MemoryLayout<T>.size
        return number;
    }

    public func getInt2() -> int2 {
        return int2(getNumber(), getNumber());
    }

    public func getInt3() -> int3 {
        return int3(getNumber(), getNumber(), getNumber());
    }

    public func getFloat2() -> float2 {
        return float2(getNumber(), getNumber());
    }

    public func getFloat3() -> float3 {
        return float3(getNumber(), getNumber(), getNumber());
    }

    public func getIndexRange() -> CountableRange<Int32> {
        let start: Int32 = getNumber();
        let size: Int32 = getNumber();

        return start ..< (start + size);
    }

    public func getString(maxLength: Int) -> String? {
        let string = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) -> String? in
            var currentPointer = pointer.advanced(by: position);

            for _ in 0 ..< maxLength {
                guard currentPointer.pointee != CChar(0) else { break }
                currentPointer = currentPointer.successor();
            }

            let endPosition = pointer.distance(to: currentPointer)
            let stringData = data.subdata(in: position ..< endPosition);

            return String(data: stringData, encoding: String.Encoding.ascii);
        };

        position += maxLength;
        return string
    }

    func subdata(in range: Range<Int>) -> BinaryParser {
        return BinaryParser(data.subdata(in: range));
    }
}
