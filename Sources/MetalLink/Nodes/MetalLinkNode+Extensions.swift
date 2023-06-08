import Foundation
import SceneKit

public extension MetalLinkNode {

    func translate(dX: Float = 0,
                   dY: Float = 0,
                   dZ: Float = 0) {
        position.x += dX
        position.y += dY
        position.z += dZ
    }
    
    func translated(dX: Float = 0,
                    dY: Float = 0,
                    dZ: Float = 0) -> Self {
        position.x += dX
        position.y += dY
        position.z += dZ
        return self
    }
    
    func apply(_ modifier: @escaping (Self) -> Void) -> Self {
        modifier(self)
        return self
    }
}
