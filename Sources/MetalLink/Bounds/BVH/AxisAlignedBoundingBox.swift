//
//
//  With thanks and appreciation to the silicon and lightning that cooperated to generate this.
//  Created on 11/16/23.
//

import Foundation

public struct AxisAlignedBoundingBox {
    public var boxMin: LFloat3
    public var boxMax: LFloat3
    
    public init(boxMin: LFloat3, boxMax: LFloat3) {
        self.boxMin = boxMin
        self.boxMax = boxMax
    }
    
    public func intersects(with other: AxisAlignedBoundingBox) -> Bool {
        return (boxMin.x <= other.boxMax.x && boxMax.x >= other.boxMin.x) 
            && (boxMin.y <= other.boxMax.y && boxMax.y >= other.boxMin.y)
            && (boxMin.z <= other.boxMax.z && boxMax.z >= other.boxMin.z)
    }
    
    public func contains(point: LFloat3) -> Bool {
        return (boxMin.x <= point.x && point.x <= boxMax.x)
            && (boxMin.y <= point.y && point.y <= boxMax.y)
            && (boxMin.z <= point.z && point.z <= boxMax.z)
    }
    
    public func union(with other: AxisAlignedBoundingBox) -> AxisAlignedBoundingBox {
        let newboxMin = LFloat3(
            min(boxMin.x, other.boxMin.x),
            min(boxMin.y, other.boxMin.y),
            min(boxMin.z, other.boxMin.z)
        )
        let newboxMax = LFloat3(
            max(boxMax.x, other.boxMax.x),
            max(boxMax.y, other.boxMax.y),
            max(boxMax.z, other.boxMax.z)
        )
        return AxisAlignedBoundingBox(boxMin: newboxMin, boxMax: newboxMax)
    }
    
    // More AABB related methods...
}
