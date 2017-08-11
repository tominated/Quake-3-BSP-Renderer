//
//  Bezier.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 24/12/2015.
//  Copyright © 2015 Thomas Brunoli. All rights reserved.
//

import Foundation

class Bezier {
    fileprivate let level: Int
    fileprivate let controls: [Q3Vertex]
    
    var vertices: [Q3Vertex] = []
    var indices: [UInt32] = []
    
    init(controls: [Q3Vertex], level: Int = 10) {
        self.level = level
        self.controls = controls
        
        // Get the vertices along the columns after being tesellated
        let v0v6 = tessellate(controls[0], controls[3], controls[6])
        let v1v7 = tessellate(controls[1], controls[4], controls[7])
        let v2v8 = tessellate(controls[2], controls[5], controls[8])
        
        
        // Calculate the final vertices by tesellating the rows from the
        // previous calculations
        for i in 0...level {
            vertices.append(contentsOf: tessellate(v0v6[i], v1v7[i], v2v8[i]))
        }
        
        // Calculate the triangles to form between the tesellated points
        let numverts = (level + 1) * (level + 1)
        let width = level + 1
        var xStep = 1
        
        for i in 0..<(numverts - width) {
            if xStep == 1 {
                // Left Edge
                indices.append(UInt32(i))
                indices.append(UInt32(i + width))
                indices.append(UInt32(i + 1))
                
                xStep += 1
            } else if xStep == width {
                // Right Edge
                indices.append(UInt32(i))
                indices.append(UInt32(i + width - 1))
                indices.append(UInt32(i + width))
                
                xStep = 1
            } else {
                // Not on edge, create two triangles
                indices.append(UInt32(i))
                indices.append(UInt32(i + width - 1))
                indices.append(UInt32(i + width))
                
                indices.append(UInt32(i))
                indices.append(UInt32(i + width))
                indices.append(UInt32(i + 1))
                
                xStep += 1
            }
        }
    }
    
    fileprivate func bezier(_ v0: Q3Vertex, _ v1: Q3Vertex, _ v2: Q3Vertex, t: Float) -> Q3Vertex {
        let a = 1 - t
        let tt = t * t
        
        // The swift compiler complains about complexity if I don't expand this
        let w = v0 * (a * a)
        let x = 2 * a
        let y = v1 * t
        let z = v2 * tt
        
        return w + y * x + z
    }
    
    fileprivate func tessellate(_ v0: Q3Vertex, _ v1: Q3Vertex, _ v2: Q3Vertex) -> [Q3Vertex] {
        var vertices: [Q3Vertex] = []
        let step = 1.0 / Float(level)
        
        for i in 0...level {
            vertices.append(bezier(v0, v1, v2, t: step * Float(i)))
        }
        
        return vertices
    }
}
