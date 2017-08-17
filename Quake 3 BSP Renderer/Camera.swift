//
//  Camera.swift
//  Quake 3 BSP Renderer
//
//  Swift implementation of camera class found at
//  https://www.reddit.com/r/opengl/comments/2k8tj6/my_quaternionbased_camera_is_moving_relative_to/clj1utw
//

import Foundation
import GLKit

class Camera {
    var position: GLKVector3 = GLKVector3Make(0, 0, 0)
    var pitch: Float = 0
    var yaw: Float = 0

    private var up: GLKVector3 = GLKVector3Make(0, 1, 0)

    private var direction: GLKVector3 {
        get {
            return GLKVector3Normalize(GLKVector3Make(
                cos(GLKMathDegreesToRadians(yaw)) * cos(GLKMathDegreesToRadians(pitch)),
                sin(GLKMathDegreesToRadians(pitch)),
                sin(GLKMathDegreesToRadians(yaw)) * cos(GLKMathDegreesToRadians(pitch))
            ))
        }
    }

    func move(joystickX: Float, joystickY: Float) {
        // Move forward and backward
        position = GLKVector3Add(
            position,
            GLKVector3MultiplyScalar(direction, -joystickY)
        )

        // Strafe side to side
        let right = GLKVector3CrossProduct(direction, up)
        position = GLKVector3Add(
            position,
            GLKVector3MultiplyScalar(right, joystickX)
        )
    }

    func point(joystickX: Float, joystickY: Float) {
        pitch = min(max(pitch - joystickY, -89), 89)
        yaw = yaw + joystickX
    }

    func getViewMatrix() -> GLKMatrix4 {
        return GLKMatrix4MakeLookAt(
            position.x,
            position.y,
            position.z,
            position.x + direction.x,
            position.y + direction.y,
            position.z + direction.z,
            up.x,
            up.y,
            up.z
        )
    }
}
