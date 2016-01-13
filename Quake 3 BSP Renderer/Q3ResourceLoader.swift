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
    let dataFiles: Array<NSURL> = []
    
    init() {}
    
    // Add a Quake 3 data file (e.g. data.pak0) to the list of data files to
    // potentially load resources from
    func addDataFile(path: NSURL) {
        // TODO: Implement this
    }
    
    // Loads the specified map from the appropriate data file if it exists
    func loadMap(name: NSURL) -> Q3Map? {
        // TODO: Implement this
        return nil
    }
    
    // Loads the specified texture as a CGImage from the appropriate data file
    // if it exists
    func loadTexture(path: NSURL) -> CGImage? {
        // TODO: Implement this
        return nil
    }
    
    // Finds a resource at path from the highest priority data file it is found
    // in, and returns the contents of is as NSData (if it can be found)
    private func loadResource(path: NSURL) -> NSData? {
        // TODO: Implement this
        return nil
    }
}