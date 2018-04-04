//
//  ViewController.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

import UIKit
import MetalKit
import simd

func getJoystick(start: CGPoint?, current: CGPoint?) -> CGPoint {
    guard let start = start, let current = current
        else { return CGPoint(x: 0, y: 0) }

    // Get x,y values for joystick between -100 and 100
    var x = min(max(current.x - start.x, -100), 100)
    var y = min(max(current.y - start.y, -100), 100)

    // Set a deadzone of -10 to 10
    if (x < 10 && x > -10) {
        x = 0
    }

    if (y < 10 && y > -10) {
        y = 0
    }

    return CGPoint(x: x, y: y)
}

class ViewController: UIViewController, MTKViewDelegate {
    var camera = Camera()
    var renderer: QuakeRenderer! = nil

    var leftTouchStart: CGPoint? = nil
    var leftTouchCurrent: CGPoint? = nil

    var rightTouchStart: CGPoint? = nil
    var rightTouchCurrent: CGPoint? = nil

    var leftJoystickView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    var rightJoystickView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

    var leftJoystick: CGPoint {
        get {
            return getJoystick(start: leftTouchStart, current: leftTouchCurrent)
        }
    }

    var rightJoystick: CGPoint {
        get {
            return getJoystick(start: rightTouchStart, current: rightTouchCurrent)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let view = self.view as! MTKView
        view.device = MTLCreateSystemDefaultDevice()

        renderer = try! QuakeRenderer(withMetalKitView: view, map: "q3dm6", camera: camera)

        view.delegate = self
        renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)

        view.isMultipleTouchEnabled = true

        leftJoystickView.isUserInteractionEnabled = false;
        leftJoystickView.backgroundColor = UIColor.init(white: 1, alpha: 0.2)
        leftJoystickView.layer.cornerRadius = leftJoystickView.frame.width / 2
        leftJoystickView.isHidden = true

        rightJoystickView.isUserInteractionEnabled = false;
        rightJoystickView.backgroundColor = UIColor.init(white: 1, alpha: 0.2)
        rightJoystickView.layer.cornerRadius = rightJoystickView.frame.width / 2
        rightJoystickView.isHidden = true

        view.addSubview(leftJoystickView)
        view.addSubview(rightJoystickView)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: view)

            if (location.x <= view.frame.width / 2) {
                // Left side of screen
                if (leftTouchStart == nil) {
                    leftTouchStart = location
                    leftTouchCurrent = location

                    leftJoystickView.frame.origin.x = location.x - (leftJoystickView.frame.width / 2)
                    leftJoystickView.frame.origin.y = location.y - (leftJoystickView.frame.height / 2)
                    leftJoystickView.isHidden = false
                }
            } else {
                // Right side of screen
                if (rightTouchStart == nil) {
                    rightTouchStart = location
                    rightTouchCurrent = location

                    rightJoystickView.frame.origin.x = location.x - (rightJoystickView.frame.width / 2)
                    rightJoystickView.frame.origin.y = location.y - (rightJoystickView.frame.height / 2)
                    rightJoystickView.isHidden = false
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
            let location = touch.location(in: view)

            if (prevLocation == leftTouchCurrent || location == leftTouchCurrent) {
                leftTouchStart = nil
                leftTouchCurrent = nil
                leftJoystickView.isHidden = true
            } else if (prevLocation == rightTouchCurrent || location == rightTouchCurrent) {
                rightTouchStart = nil
                rightTouchCurrent = nil
                rightJoystickView.isHidden = true
            }
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        camera.move(
            joystickX: Float(leftJoystick.x) / 20,
            joystickY: Float(leftJoystick.y) / 20
        )

        camera.point(
            joystickX: Float(rightJoystick.x) / 30,
            joystickY: Float(rightJoystick.y) / 30
        )

        renderer.draw(in: view)
    }
}
