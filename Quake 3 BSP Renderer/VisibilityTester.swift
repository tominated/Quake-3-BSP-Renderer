//
//  VisibilityTester.swift
//  Quake3Renderer
//
//  Created by Thomas Brunoli on 4/06/2017.
//  Copyright © 2017 Quake3Renderer. All rights reserved.
//

import simd

public class VisibilityTester {
    let nodes: Array<BSPNode>
    let leaves: Array<BSPLeaf>
    let leafFaces: Array<BSPLeafFace>
    let planes: Array<BSPPlane>
    let visdata: BSPVisdata?


    init(bsp: Quake3BSP) {
        nodes = bsp.nodes
        leaves = bsp.leaves
        leafFaces = bsp.leafFaces
        planes = bsp.planes
        visdata = bsp.visdata
    }

    func getVisibleFaceIndices(at point: float3) -> Array<Int> {
        var visibleFaces: Array<Int> = []
        var alreadyVisible: Set<Int> = []

        let pointLeaf = findLeaf(at: point)

        for leaf in self.leaves {
            if !isClusterVisible(currentCluster: pointLeaf.cluster, testCluster: leaf.cluster) {
                continue
            }

            for leafFaceIndex in leaf.leafFaceIndices.lowerBound ..< leaf.leafFaceIndices.upperBound {
                let faceIndex = Int(self.leafFaces[Int(leafFaceIndex)].faceIndex)

                if !alreadyVisible.contains(faceIndex) {
                    alreadyVisible.insert(faceIndex)
                    visibleFaces.append(faceIndex)
                }
            }
        }

        return visibleFaces
    }

    private func isClusterVisible(currentCluster: Int32, testCluster: Int32) -> Bool {
        guard let visdata = self.visdata else { return true }
        if currentCluster < 0 || testCluster < 0 { return true }

        let i = (currentCluster * visdata.vectorSize) + (testCluster >> 3)
        let visibilitySet = visdata.vectors[Int(i)]
        let bitmask = UInt8(1 << (testCluster & 7))

        return (visibilitySet & bitmask) != 0
    }

    private func findLeaf(at point: float3) -> BSPLeaf {
        var nodeIndex = 0

        while true {
            let node = self.nodes[nodeIndex]
            let plane = self.planes[Int(node.planeIndex)]

            let distance = dot(plane.normal, point) - plane.distance
            let child = (distance >= 0) ? node.leftChild : node.rightChild

            switch child {
            case .node(let i): nodeIndex = i
            case .leaf(let i): return self.leaves[i]
            }
        }
    }
}
