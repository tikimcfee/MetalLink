//
//  BoxComputing.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/26/22.
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
    
    public var width: Float {
        BoundsWidth(self)
    }
    
    public var height: Float {
        BoundsHeight(self)
    }
    
    public var length: Float {
        BoundsLength(self)
    }
}

public class BoxComputing {
    public var didSetInitial: Bool = false
    public var minX: VectorFloat = .infinity
    public var minY: VectorFloat = .infinity
    public var minZ: VectorFloat = .infinity
    
    public var maxX: VectorFloat = -.infinity
    public var maxY: VectorFloat = -.infinity
    public var maxZ: VectorFloat = -.infinity
    
    public init() {
        
    }
    
    public func consumeBounds(_ bounds: Bounds) {
        didSetInitial = true
        minX = min(bounds.min.x, minX)
        minY = min(bounds.min.y, minY)
        minZ = min(bounds.min.z, minZ)
        
        maxX = max(bounds.max.x, maxX)
        maxY = max(bounds.max.y, maxY)
        maxZ = max(bounds.max.z, maxZ)
    }
    
    public func consumeNodeSet(
        _ nodes: Set<MetalLinkNode>,
        convertingTo node: MetalLinkNode?
    ) {
        for node in nodes {
            consumeBounds(
                node.bounds
            )
        }
    }
    
    public func consumeNodes(
        _ nodes: [MetalLinkNode]
    ) {
        for node in nodes {
            consumeBounds(
                node.bounds
            )
        }
    }
    
    public func pad(_ pad: VectorFloat) {
        minX -= pad
        minY -= pad
        minZ -= pad
        
        maxX += pad
        maxY += pad
        maxZ += pad
    }
    
    public var bounds: Bounds {
        guard didSetInitial else {
            print("Bounds were never set; returning safe default")
            return .zero
        }
        return Bounds(
            LFloat3(x: minX, y: minY, z: minZ),
            LFloat3(x: maxX, y: maxY, z: maxZ)
        )
    }
}


public func BoundsWidth(_ bounds: Bounds) -> VectorFloat { abs(bounds.max.x - bounds.min.x) }
public func BoundsHeight(_ bounds: Bounds) -> VectorFloat { abs(bounds.max.y - bounds.min.y) }
public func BoundsLength(_ bounds: Bounds) -> VectorFloat { abs(bounds.max.z - bounds.min.z) }
public func BoundsTop(_ bounds: Bounds) -> VectorFloat { bounds.max.y }
public func BoundsBot(_ bounds: Bounds) -> VectorFloat { bounds.min.y }
public func BoundsLeading(_ bounds: Bounds) -> VectorFloat { bounds.min.x }
public func BoundsTrailing(_ bounds: Bounds) -> VectorFloat { bounds.max.x }
public func BoundsFront(_ bounds: Bounds) -> VectorFloat { bounds.max.z }
public func BoundsBack(_ bounds: Bounds) -> VectorFloat { bounds.min.z }
public func BoundsSize(_ bounds: Bounds) -> LFloat3 {
    LFloat3(BoundsWidth(bounds), BoundsHeight(bounds), BoundsLength(bounds))
}

public func BoundsP(_ bounds: Bounds) {
    
}

public extension LFloat3 {
    var debugString: String {
        String(
            format: "(%.4d, %.4d, %.4d)",
            x, y, z
        )
    }
}
