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

func getJoystick(start: CGPoint?, current: CGPoint?) -> CGPoint? {
    guard let start = start, let current = current
        else { return nil }

    // Get x,y values for joystick between -100 and 100
    var x = min(max(current.x - start.x, -100), 100)
    var y = -min(max(current.y - start.y, -100), 100)

    // Set a deadzone of -10 to 10
    if (x < 10 && x > -10) {
        x = 0
    }

    if (y < 10 && y > -10) {
        y = 0
    }

    return CGPoint(x: x, y: y)
}

class ViewController: UIViewController {
    var camera = Camera()
    var renderer: QuakeRenderer! = nil

    var leftTouchStart: CGPoint? = nil
    var leftTouchCurrent: CGPoint? = nil

    var rightTouchStart: CGPoint? = nil
    var rightTouchCurrent: CGPoint? = nil

    var leftJoystick: CGPoint? {
        get {
            return getJoystick(start: leftTouchStart, current: leftTouchCurrent)
        }
    }

    var rightJoystick: CGPoint? {
        get {
            return getJoystick(start: rightTouchStart, current: rightTouchCurrent)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let view = self.view as! MTKView
        view.device = MTLCreateSystemDefaultDevice()

        renderer = try! QuakeRenderer(withMetalKitView: view, map: "q3dm6", camera: camera)

        view.delegate = renderer
        renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)

        view.isMultipleTouchEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: view)

            if (location.x <= view.frame.width / 2) {
                // Left side of screen
                if (leftTouchStart == nil) {
                    leftTouchStart = location
                    leftTouchCurrent = location
                }
            } else {
                // Right side of screen
                if (rightTouchStart == nil) {
                    rightTouchStart = location
                    rightTouchCurrent = location
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let prevLocation = touch.previousLocation(in: view)
            let location = touch.location(in: view)

            if (prevLocation == leftTouchCurrent) {
                leftTouchCurrent = location
            } else if (prevLocation == rightTouchCurrent) {
                rightTouchCurrent = location
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let prevLocation = touch.previousLocation(in: view)

            if (prevLocation == leftTouchCurrent) {
                print("left touch ended")
                leftTouchStart = nil
                leftTouchCurrent = nil
            } else if (prevLocation == rightTouchCurrent) {
                print("right touch ended")
                rightTouchStart = nil
                rightTouchCurrent = nil
            }
        }
    }
}
