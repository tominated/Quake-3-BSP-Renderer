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

// TODO: Add actual resource loading
class Q3ResourceLoader {
    let data: ZZArchive
    
    init(dataFilePath: NSURL) {
        assert(dataFilePath.pathExtension == "pk3")
        self.data = try! ZZArchive(URL: dataFilePath)
    }
    
    // Returns a list of the Quake 3 maps found in the data file
    func maps() -> [String] {
        return data.entries.map { $0.fileName }.filter {
            guard let url = NSURL(string: $0) else { return false }
            return url.pathComponents?[0] == "maps" && url.pathExtension == "bsp"
        }
    }
    
    // Loads the specified map from the data file if it exists
    func loadMap(name: String) -> Q3Map? {
        let path = "maps/\(name).bsp"
        guard let map = loadResource(path) else { return nil }
        return Q3Map(data: map)
    }
    
    // Loads the specified texture as a CGImage from the data file if it exists
    func loadTexture(path: String) -> UIImage? {
        for fileType in ["jpg", "tga"] {
            if let data = loadResource("\(path).\(fileType)") {
                if fileType == "jpg" {
                    return UIImage(data: data)
                } else if fileType == "tga" {
                    return imageFromTGAData(data)
                }
            }
        }
        
        return nil
    }
    
    func loadShader(path: String) -> String? {
        guard let shader = loadResource(path) else { return nil }
        return String(data: shader, encoding: NSASCIIStringEncoding)
    }
    
    // Finds a resource at path within the data file, and returns the contents
    // as NSData if it can be found
    private func loadResource(path: String) -> NSData? {
        for entry in data.entries {
            if entry.fileName == path {
                return try! entry.newData()
            }
        }
        
        
        return nil
    }
}