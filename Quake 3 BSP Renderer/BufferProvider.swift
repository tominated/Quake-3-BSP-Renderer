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
    private var buffers: [MTLBuffer] = []
    private var nextBufferIndex: Int = 0
    private var availableBuffers: dispatch_semaphore_t
    
    init(device: MTLDevice, inflightBuffersCount: Int, bufferSize: Int) {
        self.inflightBuffersCount = inflightBuffersCount
        availableBuffers = dispatch_semaphore_create(inflightBuffersCount)
        
        for _ in 0..<inflightBuffersCount {
            buffers.append(
                device.newBufferWithLength(bufferSize, options: .CPUCacheModeDefaultCache)
            )
        }
    }
    
    func nextBuffer() -> MTLBuffer {
        dispatch_semaphore_wait(availableBuffers, DISPATCH_TIME_FOREVER)
        let buffer = buffers[nextBufferIndex]
        nextBufferIndex = (nextBufferIndex + 1) % inflightBuffersCount
        return buffer
    }
    
    func finishedWithBuffer() {
        dispatch_semaphore_signal(availableBuffers)
    }
    
    deinit {
        for _ in 0...inflightBuffersCount {
            finishedWithBuffer()
        }
    }
}
