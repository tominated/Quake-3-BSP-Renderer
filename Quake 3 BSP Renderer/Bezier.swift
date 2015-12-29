//
//  Bezier.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 24/12/2015.
//  Copyright © 2015 Thomas Brunoli. All rights reserved.
//

import Foundation

class Bezier {
    private var level: Int = 1
    private var vertices: [Vertex] = []
    private var indexes: [UInt32] = []
    private var trianglesPerRow: [Int] = []
    private var rowIndexes: [UInt32] = []

    var controls: [Vertex] = []
    
    // Translated to swift from
    // http://graphics.cs.brown.edu/games/quake/quake3.html
    // I don't understand this, so I'll have to read up on it a bit
    func tessellate(level: Int) {
        self.level = level
        
        // Number of vertices along a side is 1 + num edges
        let l1 = level + 1
        
        // Compute the vertices
        for i in 0...level {
            let a = Float(i) / Float(level)
            let b = 1 - a
            
            vertices.append(
                controls[0] * (b * b) +
                controls[3] * (2 * b * a) +
                controls[6] * (a * a)
            )
        }
        
        for i in 0...level {
            let a = Float(i) / Float(level)
            let b = 1 - a
            
            var temp : [Vertex] = []
            
            for j in 0..<3 {
                let k = 3 * j
                let t1 = controls[k + 0] * (b * b)
                let t2 = controls[k + 1] * (2 * b * a)
                let t3 = controls[k + 2] * (a * a)
                
                temp.append(t1 + t2 + t3)
            }
            
            for j in 0...level {
                let a = Float(j) / Float(level)
                let b = 1 - a
                
                vertices[i * l1 * j] =
                    temp[0] * (b * b) +
                    temp[1] * (2 * b * a) +
                    temp[2] * (a * a)
            }
        }
        
        // Compute the indices
        indexes.reserveCapacity(level * (level + 1) * 2)
        
        for row in 0...level {
            for col in 0..<level {
                indexes[(row * (level + 1) + col) * 2 + 1] = UInt32(row * l1 + col)
                indexes[(row * (level + 1) + col) * 2] = UInt32((row + 1) * l1 + col)
            }
        }
        
        trianglesPerRow.reserveCapacity(level)
        rowIndexes.reserveCapacity(level)
        
        for row in 0..<level {
            trianglesPerRow[row] = 2 * l1
            rowIndexes[row] = indexes[row * 2 * l1]
        }
    }
}