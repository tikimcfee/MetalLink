//
//  BoxComputing.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/26/22.
//

import Foundation

public typealias Bounds = (
    min: LFloat3,
    max: LFloat3
)

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
    
    public func consumeNodeSizes(
        _ nodes: [MetalLinkNode]
    ) {
        for node in nodes {
            consumeBounds(
                node.sizeBounds
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
            return (min: .zero, max: .zero)
        }
        return (
            min: LFloat3(x: minX, y: minY, z: minZ),
            max: LFloat3(x: maxX, y: maxY, z: maxZ)
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
