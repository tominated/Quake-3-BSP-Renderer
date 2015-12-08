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
    var position: GLKVector3
    var orientation: GLKQuaternion
    
    init() {
        position = GLKVector3Make(0, 0, 0)
        orientation = GLKQuaternionMakeWithAngleAndAxis(0, 1, 0, 0)
    }
    
    func rotate(rotation: GLKQuaternion) {
        orientation = GLKQuaternionNormalize(GLKQuaternionMultiply(rotation, orientation))
    }
    
    func rotate(radians: Float, x: Float, y: Float, z: Float) {
        let q = GLKQuaternionMakeWithAngleAndAxis(radians, x, y, z)
        rotate(q)
    }
    
    func pitch(radians: Float) {
        rotate(radians, x: 1, y: 0, z: 0)
    }
    
    func yaw(radians: Float) {
        rotate(radians, x: 0, y: 1, z: 0)
    }
    
    func roll(radians: Float) {
        rotate(radians, x: 0, y: 0, z: 1)
    }
    
    func turn(radians: Float) {
        let axis = GLKQuaternionRotateVector3(orientation, GLKVector3Make(0, 1, 0))
        let q = GLKQuaternionMakeWithAngleAndAxis(radians, axis.x, axis.y, axis.z)
        return rotate(q)
    }
    
    func getForward() -> GLKVector3 {
        return GLKQuaternionRotateVector3(
            GLKQuaternionConjugate(orientation),
            GLKVector3Make(0, 0, -1)
        )
    }
    
    func getLeft() -> GLKVector3 {
        return GLKQuaternionRotateVector3(
            GLKQuaternionConjugate(orientation),
            GLKVector3Make(-1, 0, 0)
        )
    }
    
    func getUp() -> GLKVector3 {
        return GLKQuaternionRotateVector3(
            GLKQuaternionConjugate(orientation),
            GLKVector3Make(0, 1, 0)
        )
    }
    
    func moveForward(movement: Float) {
        position = GLKVector3Add(
            position,
            GLKVector3MultiplyScalar(getForward(), movement)
        )
    }
    
    func getViewMatrix() -> GLKMatrix4 {
        return GLKMatrix4TranslateWithVector3(
            GLKMatrix4MakeWithQuaternion(orientation),
            GLKVector3Negate(position)
        )
    }
}