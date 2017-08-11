//
//  BufferProvider.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 9/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import Metal

class BufferProvider {
    let inflightBuffersCount: Int
    fileprivate var buffers: [MTLBuffer] = []
    fileprivate var nextBufferIndex: Int = 0
    fileprivate var availableBuffers: DispatchSemaphore
    
    init(device: MTLDevice, inflightBuffersCount: Int, bufferSize: Int) {
        self.inflightBuffersCount = inflightBuffersCount
        availableBuffers = DispatchSemaphore(value: inflightBuffersCount)
        
        for _ in 0..<inflightBuffersCount {
            buffers.append(
                device.makeBuffer(length: bufferSize, options: MTLResourceOptions())
            )
        }
    }
    
    func nextBuffer() -> MTLBuffer {
        let _ = availableBuffers.wait(timeout: DispatchTime.distantFuture)
        let buffer = buffers[nextBufferIndex]
        nextBufferIndex = (nextBufferIndex + 1) % inflightBuffersCount
        return buffer
    }
    
    func finishedWithBuffer() {
        availableBuffers.signal()
    }
    
    deinit {
        for _ in 0...inflightBuffersCount {
            finishedWithBuffer()
        }
    }
}
