//
//  ViewController.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import UIKit
import MetalKit
import GLKit

class ViewController: UIViewController {
    var camera = Camera()
    var renderer: QuakeRenderer! = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let view = self.view as! MTKView
        view.device = MTLCreateSystemDefaultDevice()

        renderer = try! QuakeRenderer(withMetalKitView: view, map: "q3dm6", camera: camera)

        view.delegate = renderer
        renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(ViewController.handlePan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(ViewController.handlePinch(_:))))
    }

    func handlePan(_ gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: self.view)
        let newPitch = GLKMathDegreesToRadians(Float(velocity.y / -100))
        let newYaw = GLKMathDegreesToRadians(Float(velocity.x / -100))

        camera.pitch(newPitch)
        camera.turn(newYaw)
    }

    func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let velocity = Float(gesture.velocity / 2)
        if velocity.isNaN || velocity < 0.1  { return }
        camera.moveForward(velocity)
    }
}
