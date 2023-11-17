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
}

public extension Bounds {
    static func * (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min *= rhs
        newBounds.max *= rhs
        return newBounds
    }
    
    static func + (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min += rhs
        newBounds.max += rhs
        return newBounds
    }
    
    static func / (lhs: Bounds, rhs: LFloat3) -> Bounds {
        var newBounds = lhs
        newBounds.min /= rhs
        newBounds.max /= rhs
        return newBounds
    }
}

public extension Bounds {
    var width: VectorFloat {
        abs(max.x - min.x)
    }
    
    var height: VectorFloat {
        abs(max.y - min.y)
    }
    
    var length: VectorFloat {
        abs(max.z - min.z)
    }
    
    var size: LFloat3 {
        LFloat3(
            width,
            height,
            length
        )
    }

    var top: VectorFloat {
        max.y
    }

    var bottom: VectorFloat {
        min.y
    }

    var leading: VectorFloat {
        min.x
    }

    var trailing: VectorFloat {
        max.x
    }

    var front: VectorFloat {
        max.z
    }

    var back: VectorFloat {
        min.z
    }

    var center: LFloat3 {
        LFloat3(
            min.x + (width / 2),
            min.y - (height / 2),
            min.z + (length / 2)
        )
    }
}

public extension Bounds {
    static let zero = Bounds(.zero, .zero)
    
    static let forBaseComputing =
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
}

public extension Bounds {
    func intersects(with other: Bounds) -> Bool {
        return (min.x <= other.max.x && max.x >= other.min.x)
            && (min.y <= other.max.y && max.y >= other.min.y)
            && (min.z <= other.max.z && max.z >= other.min.z)
    }
    
    func contains(point: LFloat3) -> Bool {
        return (min.x <= point.x && point.x <= max.x)
            && (min.y <= point.y && point.y <= max.y)
            && (min.z <= point.z && point.z <= max.z)
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

