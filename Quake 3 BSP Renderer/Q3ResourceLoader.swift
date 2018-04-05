//
//  Q3ResourceLoader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import QuartzCore
import zipzap

private var SHADER_WHITELIST: Set<String> = [
    "scripts/base_button.shader", "scripts/base_floor.shader",
    "scripts/base_light.shader", "scripts/base_object.shader", "scripts/base_support.shader",
    "scripts/base_trim.shader", "scripts/base_wall.shader", "scripts/common.shader",
    "scripts/ctf.shader", "scripts/gfx.shader",
    "scripts/gothic_block.shader", "scripts/gothic_floor.shader", "scripts/gothic_light.shader",
    "scripts/gothic_trim.shader", "scripts/gothic_wall.shader",
    "scripts/liquid.shader", "scripts/models.shader",
    "scripts/organics.shader", "scripts/sfx.shader",
    "scripts/skin.shader", "scripts/sky.shader"
]

class Q3ResourceLoader {
    let data: ZZArchive
    
    init(dataFilePath: URL) {
        assert(dataFilePath.pathExtension == "pk3")
        self.data = try! ZZArchive(url: dataFilePath)
    }
    
    // Returns a list of the Quake 3 maps found in the data file
    func maps() -> [String] {
        return data.entries.map { $0.fileName }.filter {
            guard let url = URL(string: $0) else { return false }
            return url.pathComponents[0] == "maps" && url.pathExtension == "bsp"
        }
    }
    
    // Loads the specified map from the data file if it exists
    func loadMap(_ name: String) -> Q3Map? {
        let path = "maps/\(name).bsp"
        guard let map = loadResource(path) else { return nil }
        return Q3Map(data: map)
    }
    
    // Loads the specified texture as a CGImage from the data file if it exists
    func loadTexture(_ path: String) -> UIImage? {
        // This is to remove any extention from the path
        let splitPath = path.split{ $0 == "." }
        
        for fileType in ["jpg", "tga"] {
            if let data = loadResource("\(splitPath[0]).\(fileType)") {
                if fileType == "jpg" {
                    return UIImage(data: data)
                } else if fileType == "tga" {
                    return imageFromTGAData(data)
                }
            }
        }
        
        return nil
    }
    
    func loadShader(_ path: String) -> String? {
        guard let shader = loadResource(path) else { return nil }
        return String(data: shader, encoding: String.Encoding.ascii)
    }
    
    func loadAllShaders() -> String {
        return data.entries
            .map({ $0.fileName })
            .filter({ SHADER_WHITELIST.contains($0) })
            .flatMap({ loadShader($0) })
            .joined(separator: "\n")
    }
    
    // Finds a resource at path within the data file, and returns the contents
    // as NSData if it can be found
    fileprivate func loadResource(_ path: String) -> Data? {
        for entry in data.entries {
            if entry.fileName == path {
                return try! entry.newData()
            }
        }
        
        
        return nil
    }
}
