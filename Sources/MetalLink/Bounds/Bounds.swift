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
            min.y + (height / 2),
            min.z + (length / 2)
        )
    }
    
    var leadingTopFront: LFloat3 { LFloat3(leading, top, front) }
    var trailingTopFront: LFloat3 { LFloat3(trailing, top, front) }
    
    var leadingBottomFront: LFloat3 { LFloat3(leading, bottom, front) }
    var trailingBottomFront: LFloat3 { LFloat3(trailing, bottom, front) }
    
    var leadingTopBack: LFloat3 { LFloat3(leading, top, back) }
    var trailingTopBack: LFloat3 { LFloat3(trailing, top, back) }
    
    var leadingBottomBack: LFloat3 { LFloat3(leading, bottom, back) }
    var trailingBottomBack: LFloat3 { LFloat3(trailing, bottom, back) }
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

/// Checks if the current bounds are entirely inside another set of bounds.
/// - Parameter otherBounds: The bounds to compare with for containment.
/// - Returns: A boolean indicating whether the current bounds are entirely inside the other bounds.
public extension Bounds {
    func isEntirelyInside(other otherBounds: Bounds) -> Bool {
        let isInsideX = (min.x >= otherBounds.min.x && max.x <= otherBounds.max.x)
        let isInsideY = (min.y >= otherBounds.min.y && max.y <= otherBounds.max.y)
        let isInsideZ = (min.z >= otherBounds.min.z && max.z <= otherBounds.max.z)
        
        return isInsideX && isInsideY && isInsideZ
    }
}

/// Checks if a ray intersects with the bounds.
/// This function calculates the intersection DISTANCES at which the ray
/// intersects each plane of the bounding box along the X, Y and Z axes.
///
/// For each axis, it computes two intersection distances:
/// 1) The near plane intersection distance
/// 2) The far plane intersection distance
///
/// The near plane intersection distance represents the shortest distance
/// along the ray at which it intersects the bounding box.
/// The far plane intersection distance is the longest distance.
///
/// To check if the ray intersects the box, we compare:
/// 1) The longest near plane intersection distance overall
///    (the earliest the ray can enter the box)
///
/// 2) The shortest far plane intersection distance overall
///    (the last point at which the ray exits the box)
///
/// If the longest near plane distance is less than or equal to the
/// shortest far plane distance, it means the line entered and exited the box
/// volume and hence intersects the bounding box.
/// - Parameters:
///   - rayOrigin: The origin point of the ray.
///   - rayDirection: The directional vector of the ray.
/// - Returns: A boolean indicating whether the ray intersects the bounds.
public extension Bounds {
    func intersectsRay(
        rayOrigin origin: LFloat3,
        rayDirection direction: LFloat3
    ) -> Bool {
        let inverseDirectionX = 1.0 / direction.x
        let inverseDirectionY = 1.0 / direction.y
        let inverseDirectionZ = 1.0 / direction.z

        let intersectionMinX = (min.x - origin.x) * inverseDirectionX
        let intersectionMaxX = (max.x - origin.x) * inverseDirectionX
        let intersectionMinY = (min.y - origin.y) * inverseDirectionY
        let intersectionMaxY = (max.y - origin.y) * inverseDirectionY
        let intersectionMinZ = (min.z - origin.z) * inverseDirectionZ
        let intersectionMaxZ = (max.z - origin.z) * inverseDirectionZ

        // Calculating min and max intersection times for each axis.
        let minXIntersection = Swift.min(intersectionMinX, intersectionMaxX)
        let maxXIntersection = Swift.max(intersectionMinX, intersectionMaxX)
        
        let minYIntersection = Swift.min(intersectionMinY, intersectionMaxY)
        let maxYIntersection = Swift.max(intersectionMinY, intersectionMaxY)
        
        let minZIntersection = Swift.min(intersectionMinZ, intersectionMaxZ)
        let maxZIntersection = Swift.max(intersectionMinZ, intersectionMaxZ)

        // Finding overall min and max intersections.
        let overallMinIntersection = Swift.max(
            Swift.max(minXIntersection, minYIntersection),
            minZIntersection
        )
        let overallMaxIntersection = Swift.min(
            Swift.min(maxXIntersection, maxYIntersection),
            maxZIntersection
        )

        return overallMaxIntersection >= Swift.max(overallMinIntersection, 0.0)
    }
}
