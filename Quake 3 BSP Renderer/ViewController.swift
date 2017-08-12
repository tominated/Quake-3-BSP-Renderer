//
//  ViewController.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    var renderer: QuakeRenderer! = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let view = self.view as! MTKView
        view.device = MTLCreateSystemDefaultDevice()

        renderer = try! QuakeRenderer(withMetalKitView: view, andMap: "test_bigbox")

        view.delegate = renderer
        renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)
    }
}
