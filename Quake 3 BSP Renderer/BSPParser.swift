//
//  Quake3BSPParser.swift
//  Quake3BSPParser
//
//  Created by Thomas Brunoli on {TODAY}.
//  Copyright © 2017 Quake3BSPParser. All rights reserved.
//

import Foundation
import simd

// Directory:
let ENTITIES_INDEX = 0;
let TEXTURES_INDEX = 1;
let PLANES_INDEX = 2;
let NODES_INDEX = 3;
let LEAVES_INDEX = 4;
let LEAF_FACES_INDEX = 5;
let LEAF_BRUSHES_INDEX = 6;
let MODELS_INDEX = 7;
let BRUSHES_INDEX = 8;
let BRUSH_SIDES_INDEX = 9;
let VERTICES_INDEX = 10;
let MESH_VERTS_INDEX = 11;
let EFFECTS_INDEX = 12;
let FACES_INDEX = 13;
let LIGHTMAPS_INDEX = 14;
let LIGHT_VOLS_INDEX = 15;
let VISDATA_INDEX = 16;

func colorToFloat4(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> float4 {
    return float4(
        Float(r) / 255,
        Float(g) / 255,
        Float(b) / 255,
        Float(a) / 255
    )
}

public class Quake3BSPParser {
    let parser: BinaryParser;
    var directory: Array<Range<Int>> = [];
    var bsp = Quake3BSP();

    public enum ParseError: Error {
        case invalidBSP(reason: String);
    }

    public init(bspData data: Data) throws {
        parser = BinaryParser(data);
        try parseHeader();
    }

    public func parse() throws -> Quake3BSP {
        try parseEntities();
        try parseTextures();
        try parsePlanes();
        try parseNodes();
        try parseLeaves();
        try parseLeafFaces();
        try parseLeafBrushes();
        try parseModels();
        try parseBrushes();
        try parseBrushSides();
        try parseVertices();
        try parseMeshVerts();
        try parseEffects();
        try parseFaces();
        try parseLightmaps();
        try parseLightVols();
        try parseVisdata();

        return bsp
    }

    // Parse the header of a Quake 3 BSP file and return the directory
    private func parseHeader() throws {
        // Ensure the 'magic' value is correct
        guard parser.getString(maxLength: 4) == "IBSP" else {
            throw ParseError.invalidBSP(reason: "Magic value not IBSP");
        }

        // Ensure the version is correct
        let version: Int32 = parser.getNumber();
        guard version == 0x2e else {
            throw ParseError.invalidBSP(reason: "Version not 0x2e");
        }

        // Get the directory entry index/lengths (as ranges)
        for _ in 0 ..< 17 {
            let start: Int32 = parser.getNumber();
            let size: Int32 = parser.getNumber();

            directory.append(Int(start) ..< Int(start + size));
        }
    }

    private func parseEntities() throws {
        let entry = directory[ENTITIES_INDEX];
        parser.jump(to: entry.lowerBound);

        guard let entities = parser.getString(maxLength: entry.count) else {
            throw ParseError.invalidBSP(reason: "Error parsing entities");
        };

        bsp.entities = BSPEntities(entities: entities);
    }

    private func parseTextures() throws {
        bsp.textures = try readEntry(index: TEXTURES_INDEX, entryLength: 72) { reader in
            guard let name = parser.getString(maxLength: 64) else {
                throw ParseError.invalidBSP(reason: "Error parsing texture name");
            }

            return BSPTexture(
                name: name,
                surfaceFlags: parser.getNumber(),
                contentFlags: parser.getNumber()
            );
        }
    }

    private func parsePlanes() throws {
        bsp.planes = try readEntry(index: PLANES_INDEX, entryLength: 16) { reader in
            return BSPPlane(
                normal: parser.getFloat3(),
                distance: parser.getNumber()
            );
        }
    }

    private func parseNodes() throws {
        bsp.nodes = try readEntry(index: NODES_INDEX, entryLength: 36) { reader in
            let planeIndex: Int32 = parser.getNumber();
            let leftChildRaw: Int32 = parser.getNumber();
            let rightChildRaw: Int32 = parser.getNumber();
            let boundingBoxMin = parser.getInt3();
            let boundingBoxMax = parser.getInt3();

            let leftChild: BSPNode.NodeChild = leftChildRaw < 0
                ? .leaf(-(Int(leftChildRaw) + 1))
                : .node(Int(leftChildRaw))

            let rightChild: BSPNode.NodeChild = rightChildRaw < 0
                ? .leaf(-(Int(rightChildRaw) + 1))
                : .node(Int(rightChildRaw))

            return BSPNode(
                planeIndex: planeIndex,
                leftChild: leftChild,
                rightChild: rightChild,
                boundingBoxMin: boundingBoxMin,
                boundingBoxMax: boundingBoxMax
            );
        }
    }

    private func parseLeaves() throws {
        bsp.leaves = try readEntry(index: LEAVES_INDEX, entryLength: 48) { reader in
            return BSPLeaf(
                cluster: parser.getNumber(),
                area: parser.getNumber(),
                boundingBoxMin: parser.getInt3(),
                boundingBoxMax: parser.getInt3(),
                leafFaceIndices: parser.getIndexRange(),
                leafBrushIndices: parser.getIndexRange()
            );
        }
    }

    private func parseLeafFaces() throws {
        bsp.leafFaces = try readEntry(index: LEAF_FACES_INDEX, entryLength: 4) { reader in
            return BSPLeafFace(faceIndex: parser.getNumber());
        }
    }

    private func parseLeafBrushes() throws {
        bsp.leafBrushes = try readEntry(index: LEAF_BRUSHES_INDEX, entryLength: 4) { reader in
            return BSPLeafBrush(brushIndex: parser.getNumber());
        }
    }

    private func parseModels() throws {
        bsp.models = try readEntry(index: MODELS_INDEX, entryLength: 40) { reader in
            return BSPModel(
                boundingBoxMin: parser.getFloat3(),
                boundingBoxMax: parser.getFloat3(),
                faceIndices: parser.getIndexRange(),
                brushIndices: parser.getIndexRange()
            );
        }
    }

    private func parseBrushes() throws {
        bsp.brushes = try readEntry(index: BRUSHES_INDEX, entryLength: 12) { reader in
            return BSPBrush(
                brushSideIndices: parser.getIndexRange(),
                textureIndex: parser.getNumber()
            );
        }
    }

    private func parseBrushSides() throws {
        bsp.brushSides = try readEntry(index: BRUSH_SIDES_INDEX, entryLength: 8) { reader in
            return BSPBrushSide(
                planeIndex: parser.getNumber(),
                textureIndex: parser.getNumber()
            );
        }
    }

    private func parseVertices() throws {
        bsp.vertices = try readEntry(index: VERTICES_INDEX, entryLength: 44) { reader in
            return BSPVertex(
                position: parser.getFloat3(),
                surfaceTextureCoord: parser.getFloat2(),
                lightmapTextureCoord: parser.getFloat2(),
                normal: parser.getFloat3(),
                color: colorToFloat4(parser.getNumber(), parser.getNumber(), parser.getNumber(), parser.getNumber())
            )
        }
    }

    private func parseMeshVerts() throws {
        bsp.meshVerts = try readEntry(index: MESH_VERTS_INDEX, entryLength: 4) { reader in
            return BSPMeshVert(vertexIndexOffset: parser.getNumber());
        }
    }

    private func parseEffects() throws {
        bsp.effects = try readEntry(index: EFFECTS_INDEX, entryLength: 72) { reader in
            guard let name = parser.getString(maxLength: 64) else {
                throw ParseError.invalidBSP(reason: "Error parsing effect name");
            }

            return BSPEffect(
                name: name,
                brushIndex: parser.getNumber()
            );
        }
    }

    private func parseFaces() throws {
        bsp.faces = try readEntry(index: FACES_INDEX, entryLength: 104) { reader in
            let textureIndex: Int32 = parser.getNumber();
            let effectIndex: Int32 = parser.getNumber();

            guard let faceType = BSPFace.FaceType(rawValue: parser.getNumber()) else {
                throw ParseError.invalidBSP(reason: "Error parsing face type");
            }

            return BSPFace(
                textureIndex: textureIndex,
                effectIndex: effectIndex >= 0 ? effectIndex : nil,
                type: faceType,
                vertexIndices: parser.getIndexRange(),
                meshVertIndices: parser.getIndexRange(),
                lightmapIndex: parser.getNumber(),
                lightmapStart: parser.getInt2(),
                lightmapSize: parser.getInt2(),
                lightmapOrigin: parser.getFloat3(),
                lightmapSVector: parser.getFloat3(),
                lightmapTVector: parser.getFloat3(),
                normal: parser.getFloat3(),
                size: parser.getInt2()
            )
        }
    }

    private func parseLightmaps() throws {
        bsp.lightmaps = try readEntry(index: LIGHTMAPS_INDEX, entryLength: 128 * 128 * 3) { reader in
            var lightmap: Array<(UInt8, UInt8, UInt8)> = [];

            for _ in 0 ..< (128 * 128) {
                lightmap.append((parser.getNumber(), parser.getNumber(), parser.getNumber()))
            }

            return BSPLightmap(lightmap: lightmap);
        }
    }

    private func parseLightVols() throws {
        bsp.lightVols = try readEntry(index: LIGHT_VOLS_INDEX, entryLength: 8) { reader in
            return BSPLightVol(
                ambientColor: (parser.getNumber(), parser.getNumber(), parser.getNumber()),
                directionalColor: (parser.getNumber(), parser.getNumber(), parser.getNumber()),
                direction: (parser.getNumber(), parser.getNumber())
            )
        }
    }

    private func parseVisdata() throws {
        let entry = directory[VISDATA_INDEX];

        guard entry.count > 0 else {
            print("No visdata")
            return
        }

        parser.jump(to: entry.lowerBound);

        let numVectors: Int32 = parser.getNumber();
        let vectorSize: Int32 = parser.getNumber();

        var visdata: Array<UInt8> = [];
        for _ in 0 ..< (numVectors * vectorSize) {
            visdata.append(parser.getNumber())
        }

        bsp.visdata = BSPVisdata(
            numVectors: numVectors,
            vectorSize: vectorSize,
            vectors: visdata
        )
    }

    // Parse an entry with a closure for each item in the entry
    private func readEntry<T>(
        index: Int,
        entryLength: Int,
        each: (BinaryParser) throws -> T?
        ) throws -> Array<T> {
        guard index < directory.count else {
            throw ParseError.invalidBSP(reason: "Directory entry not found");
        }

        let entry = directory[index];
        let subParser = parser.subdata(in: entry);
        let numItems = entry.count / entryLength;
        var accumulator: Array<T> = [];
        
        for i in 0 ..< numItems {
            subParser.jump(to: i * entryLength);
            
            if let value = try each(subParser) {
                accumulator.append(value);
            }
        }
        
        return accumulator;
    }
}
