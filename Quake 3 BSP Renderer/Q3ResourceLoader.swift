//
//  Q3ResourceLoader.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/01/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import QuartzCore

// TODO: Add actual resource loading
class Q3ResourceLoader {
    let data: NSData
    
    init(dataFilePath: NSURL) {
        assert(dataFilePath.pathExtension == "pk3")
        self.data = NSData(contentsOfFile: dataFilePath.absoluteString)!
    }
    
    // Returns a list of the Quake 3 maps found in the data file
    func maps() -> [String] {
        // TODO: Implement this
        return []
    }
    
    // Loads the specified map from the data file if it exists
    func loadMap(name: String) -> Q3Map? {
        // TODO: Implement this
        return nil
    }
    
    // Loads the specified texture as a CGImage from the data file if it exists
    func loadTexture(path: String) -> CGImage? {
        // TODO: Implement this
        return nil
    }
    
    // Finds a resource at path within the data file, and returns the contents
    // as NSData if it can be found
    private func loadResource(path: String) -> NSData? {
        // TODO: Implement this
        return nil
    }
}