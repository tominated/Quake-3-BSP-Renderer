//
//  BezierPatch.swift
//  BezierPatch
//
//  Created by Thomas Brunoli on 30/05/2017.
//  Copyright © 2017 Thomas Brunoli. All rights reserved.
//

import simd

class BezierPatch {
    let faceVertices: Array<BSPVertex>
    let width: Int
    let height: Int

    init(faceVertices: Array<BSPVertex>, size: int2) {
        self.faceVertices = faceVertices
        self.width = Int(size.x)
        self.height = Int(size.y)
    }

    func buildFace() -> (Array<BSPVertex>, Array<UInt32>) {
        var vertices: Array<BSPVertex> = []
        var indices: Array<UInt32> = []

        // Lay out the face vertices on a grid
        var faceVertexGrid: Array<Array<BSPVertex>> = Array(
            repeating: Array(repeating: faceVertices[0], count: height),
            count: width
        )

        for (index, vertex) in faceVertices.enumerated() {
            let x = index % width
            let y = index / width
            faceVertexGrid[x][y] = vertex
        }

        let numPatchesX = (width - 1) / 2
        let numPatchesY = (height - 1) / 2
        let numPatches = numPatchesX * numPatchesY

        // Generate the bezier patches and add them to the vertex/index arrays
        for patchIndex in 0 ..< numPatches {
            // Find the x and y value of this patch in the grid
            let xStep = patchIndex % numPatchesX
            let yStep = patchIndex / numPatchesX

            let vi = 2 * xStep
            let vj = 2 * yStep
            var controlPoints: Array<BSPVertex> = []

            for i in 0 ..< 3 {
                for j in 0 ..< 3 {
                    controlPoints.append(faceVertexGrid[vi + j][vj + i])
                }
            }

            let (patchVertices, patchIndices) = tesselateBezierPatch(controlPoints: controlPoints)
            indices.append(contentsOf: patchIndices.map { UInt32($0 + vertices.count) })
            vertices.append(contentsOf: patchVertices)
        }

        return (vertices, indices)
    }
}

// Bezier curve function.
// v0: Starting point
// v1: Anchor point
// v2: Finishing point
// t: Time (between 0 and 1)
private func bezier(_ v0: BSPVertex, _ v1: BSPVertex, _ v2: BSPVertex, t: Float) -> BSPVertex {
    let a = 1 - t
    let tt = t * t

    let w = v0 * (a * a)
    let x = 2 * a
    let y = v1 * t
    let z = v2 * tt

    return w + y * x + z
}

// Tesselate a single row/column
private func tessellate(_ v0: BSPVertex, _ v1: BSPVertex, _ v2: BSPVertex, level: Int) -> Array<BSPVertex> {
    var vertices: Array<BSPVertex> = []
    let step = 1.0 / Float(level)

    for i in 0...level {
        vertices.append(bezier(v0, v1, v2, t: step * Float(i)))
    }

    return vertices
}

public func tesselateBezierPatch(
    controlPoints controls: Array<BSPVertex>,
    levelOfDetail level: Int = 10
    ) -> (vertices: Array<BSPVertex>, indices: Array<Int>) {
    var vertices: Array<BSPVertex> = [];
    var indices: Array<Int> = [];

    // Get the vertices along the columns after being tesellated
    let v0v6 = tessellate(controls[0], controls[3], controls[6], level: level)
    let v1v7 = tessellate(controls[1], controls[4], controls[7], level: level)
    let v2v8 = tessellate(controls[2], controls[5], controls[8], level: level)

    // Calculate the final vertices by tesellating the rows from the
    // previous calculations
    for i in 0...level {
        let column = tessellate(v0v6[i], v1v7[i], v2v8[i], level: level)
        vertices.append(contentsOf: column)
    }

    // Calculate the triangles to form between the tesellated points
    let numverts = (level + 1) * (level + 1)
    let width = level + 1

    for i in 0..<(numverts - width) {
        // Used to determine if it's an edge or middle
        let xStep = i % width

        if xStep == 0 {
            // Left Edge
            indices.append(i)
            indices.append(i + width)
            indices.append(i + 1)
        } else if xStep == (width - 1) {
            // Right Edge
            indices.append(i)
            indices.append(i + width - 1)
            indices.append(i + width)
        } else {
            // Not on edge, create two triangles
            indices.append(i)
            indices.append(i + width - 1)
            indices.append(i + width)

            indices.append(i)
            indices.append(i + width)
            indices.append(i + 1)
        }
    }

    return (vertices, indices)
}
