//  
//
//  Created on 11/16/23.
//  

import Foundation

// Rename this to 'Box'
public struct Bounds {
    public var min: LFloat3
    public var max: LFloat3
    
    init(
        _ min: LFloat3,
        _ max: LFloat3
    ) {
        self.min = min
        self.max = max
    }
    
    public static let zero = Bounds(.zero, .zero)
    public static let forBaseComputing = 
        Bounds(
            LFloat3(
                VectorFloat.infinity,
                VectorFloat.infinity,
                VectorFloat.infinity
            ),
            LFloat3(
                -VectorFloat.infinity,
                -VectorFloat.infinity,
                -VectorFloat.infinity
            )
        )
    
    public static func * (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min *= rhs
        newBounds.max *= rhs
        return newBounds
    }
    
    public static func + (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min += rhs
        newBounds.max += rhs
        return newBounds
    }
    
    public static func / (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min /= rhs
        newBounds.max /= rhs
        return newBounds
    }
    
    public var width: VectorFloat {
        abs(max.x - min.x)
    }
    
    public var height: VectorFloat {
        abs(max.y - min.y)
    }
    
    public var length: VectorFloat {
        abs(max.z - min.z)
    }
    
    public var size: LFloat3 {
        LFloat3(
            width,
            height,
            length
        )
    }

    public var top: VectorFloat {
        max.y
    }

    public var bottom: VectorFloat {
        min.y
    }

    public var leading: VectorFloat {
        min.x
    }

    public var trailing: VectorFloat {
        max.x
    }

    public var front: VectorFloat {
        max.z
    }

    public var back: VectorFloat {
        min.z
    }

    public var center: LFloat3 {
        LFloat3(
            min.x + (width / 2),
            min.y - (height / 2),
            min.z + (length / 2)
        )
    }
}

public extension Bounds {
    func createUnion(from other: Bounds) -> Bounds {
        let newMin = LFloat3(
            Swift.min(min.x, other.min.x),
            Swift.min(min.y, other.min.y),
            Swift.min(min.z, other.min.z)
        )
        let newMax = LFloat3(
            Swift.max(max.x, other.max.x),
            Swift.max(max.y, other.max.y),
            Swift.max(max.z, other.max.z)
        )
        return Bounds(newMin, newMax)
    }
    
    mutating func union(with other: Bounds) {
        self.min = LFloat3(
            Swift.min(min.x, other.min.x),
            Swift.min(min.y, other.min.y),
            Swift.min(min.z, other.min.z)
        )
        self.max = LFloat3(
            Swift.max(max.x, other.max.x),
            Swift.max(max.y, other.max.y),
            Swift.max(max.z, other.max.z)
        )
    }
}

