//  
//
//  Created on 12/16/23.
//  

import MetalKit
import Combine
import simd
import BitHandling

public enum MetalLinkCameraType {
    case Debug
}

public protocol MetalLinkCamera: AnyObject {
    var type: MetalLinkCameraType { get }
    var position: LFloat3 { get set }
    var rotation: LFloat3 { get set }
    var projectionMatrix: matrix_float4x4 { get }
    
    var worldUp: LFloat3 { get }
    var worldRight: LFloat3 { get }
    var worldFront: LFloat3 { get }
    
    func moveCameraLocation(_ dX: Float, _ dY: Float, _ dZ: Float)
}

public extension MetalLinkCamera {
    func moveCameraLocation(_ delta: LFloat3) {
        moveCameraLocation(delta.x, delta.y, delta.z)
    }
}

