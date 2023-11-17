//
//  CodeGrid+Measures.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 12/6/21.
//

import Foundation
import SceneKit
import simd

// MARK: -- Measuring and layout

public protocol Measures: AnyObject {
    var nodeId: String { get }
    
    
    
    var position: LFloat3 { get set }
    var worldPosition: LFloat3 { get set }
    
    var sizeBounds: Bounds { get }
    var bounds: Bounds { get }
    var worldBounds: Bounds { get }
    
    var hasIntrinsicSize: Bool { get }
    var contentBounds: Bounds { get }
    
    var asNode: MetalLinkNode { get }
    var parent: MetalLinkNode? { get set }
    func convertPosition(_ position: LFloat3, to: MetalLinkNode?) -> LFloat3
}

// MARK: - Position

public extension Measures {
    var xpos: VectorFloat {
        get { position.x }
        set { position.x = newValue }
    }
    
    var ypos: VectorFloat {
        get { position.y }
        set { position.y = newValue }
    }
    
    var zpos: VectorFloat {
        get { position.z }
        set { position.z = newValue }
    }
}

// MARK: - Size
public extension Measures {
    var contentHalfWidth: Float { contentBounds.width / 2.0 }
    var contentHalfHeight: Float { contentBounds.height / 2.0 }
    var contentHalfLength: Float { contentBounds.length / 2.0 }
}

// MARK: - Bounds

public extension Measures {
    var boundsWidth: VectorFloat {
        let currentBounds = bounds
        return currentBounds.width
    }
    var boundsHeight: VectorFloat {
        let currentBounds = bounds
        return currentBounds.height
    }
    var boundsLength: VectorFloat {
        let currentBounds = bounds
        return currentBounds.length
    }
    
    var boundsCenterWidth: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.x + currentBounds.width / 2.0
    }
    
    var boundsCenterHeight: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.y - currentBounds.height / 2.0
    }
    
    var boundsCenterLength: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.z + currentBounds.length / 2.0
    }
    
    var boundsCenterPosition: LFloat3 {
        let vector = LFloat3(
            x: boundsCenterWidth,
            y: boundsCenterHeight,
            z: boundsCenterLength
        )
        return vector
    }
}

// MARK: - Named positions

public extension Measures {
    var leading: VectorFloat  { bounds.min.x  }
    var trailing: VectorFloat { bounds.max.x  }
    
    var top: VectorFloat      { bounds.max.y  }
    var bottom: VectorFloat   { bounds.min.y  }
    
    var front: VectorFloat    { bounds.max.z  }
    var back: VectorFloat     { bounds.min.z  }
}

public extension Measures {
    @discardableResult
    func setLeading(_ newValue: VectorFloat) -> Self {
        let delta = newValue - leading
        xpos += delta
        return self
    }
    
    @discardableResult
    func setTrailing(_ newValue: VectorFloat) -> Self{
        let delta = newValue - trailing
        xpos += delta
        return self
    }
    
    @discardableResult
    func setTop(_ newValue: VectorFloat) -> Self {
        let delta = newValue - top
        ypos += delta
        return self
    }
    
    @discardableResult
    func setBottom(_ newValue: VectorFloat) -> Self {
        let delta = newValue - bottom
        ypos += delta
        return self
    }
    
    @discardableResult
    func setFront(_ newValue: VectorFloat) -> Self {
        let delta = newValue - front
        zpos += delta
        return self
    }
    
    @discardableResult
    func setBack(_ newValue: VectorFloat) -> Self {
        let delta = newValue - back
        zpos += delta
        return self
    }
}

extension MetalLinkNode {
    /*
     A suggestion was to use the matrix itself to account for non-translation changes,
     but it doesn't work here because, at the moment, the parent is already applied.
     Can (re)separate parent from child computations if this ends up being needed. Likely it is.
     //        if let finalMatrix = final?.modelMatrix {
     //            position = position.preMultiplied(matrix: finalMatrix)
     //        }
     */
    public func convertPosition(_ convertTarget: LFloat3, to final: MetalLinkNode?) -> LFloat3 {
        var position: LFloat3 = convertTarget
        var nodeParent = parent
        while !(nodeParent == final || nodeParent == nil) {
            position += nodeParent?.position ?? .zero
            nodeParent = nodeParent?.parent
        }
        // Stopped at 'final'; add the final position manually
        position += final?.position ?? .zero
        return position
    }
}

extension MetalLinkNode {
    
    
    public var worldPosition: LFloat3 {
        get {
            var finalPosition: LFloat3 = position
            var nodeParent = parent
            while let parent = nodeParent {
                finalPosition += parent.position
                nodeParent = parent.parent
            }
            return finalPosition
        }
        set {
            var finalPosition: LFloat3 = newValue
            var nodeParent = parent
            while let parent = nodeParent {
                finalPosition += parent.position
                nodeParent = parent.parent
            }
            position = finalPosition
        }
    }
    
    public var worldBounds: Bounds {
        var finalBounds = sizeBounds
        var nextParent = parent
        while let parent = nextParent {
            finalBounds.min += parent.position
            finalBounds.max += parent.position
            nextParent = parent.parent
        }
        return finalBounds
    }
}


public extension Measures {
    
    func computeLocalSize() -> Bounds {
        var totalBounds = Bounds.forBaseComputing

        for childNode in asNode.children {
            let childSize = childNode.computeLocalBounds()
            totalBounds.union(with: childSize)
        }
        
        if hasIntrinsicSize {
            let size = contentBounds
            let offsetSize = size + position
            totalBounds.union(with: offsetSize)
        }
        
        return totalBounds
    }
    
    func computeLocalBounds() -> Bounds {
        var size = computeLocalSize()
        size.min = convertPosition(size.min, to: parent)
        size.max = convertPosition(size.max, to: parent)
        return size
    }
}

//extension Measures {
//
//    var boundingBox: AxisAlignedBoundingBox {
//        // Compute the bounding box based on the node's geometry and transform
//        // This is a placeholder implementation and should be replaced with actual computation
//        let bounds = computeLocalBounds()
//        return AxisAlignedBoundingBox(
//            boxMin: bounds.min,
//            boxMax: bounds.max
//        )
//    }
//
//    func computeAxisAlignedBoxInLocalSpace() -> AxisAlignedBoundingBox {
//        // Use the BoundingVolumeHierarchy to compute the bounding box
//        let boundingVolumeHierarchy = BoundingVolumeHierarchy()
//        boundingVolumeHierarchy.insert(node: asNode)
//        let axisAlignedBoundingBox = boundingVolumeHierarchy.computeBounds()
//        return axisAlignedBoundingBox
//    }
//
//    func computeSize() -> Bounds {
//        let computing = BoxComputing()
//
//        for childNode in asNode.children {
//            var childSize = childNode.computeSize()
//            childSize.min = convertPosition(childSize.min, to: parent)
//            childSize.max = convertPosition(childSize.max, to: parent)
//            computing.consumeBounds(childSize)
//        }
//
//        if hasIntrinsicSize {
//            let size = contentBounds
//            let min = LFloat3(position.x + offset.x,
//                              position.y + offset.y - size.y,
//                              position.z + offset.z)
//            let max = LFloat3(position.x + offset.x + size.x,
//                              position.y + offset.y,
//                              position.z + offset.z + size.z)
//            computing.consumeBounds(Bounds(min: min, max: max))
//        }
//        let finalBounds = computing.bounds
//        return finalBounds
//    }
//
//    func computeBoundingBox() -> Bounds {
//        var size = computeSize()
//        size.min = convertPosition(size.min, to: parent)
//        size.max = convertPosition(size.max, to: parent)
//        return size
//    }
// 
//
//}

public extension Measures {
    var dumpstats: String {
        """
        ContentBoundsMin:                \(contentBounds.min)
        ContentBoundsMax:                \(contentBounds.max)
        
        nodePosition:                    \(position)
        worldPosition:                   \(worldPosition)

        boundsMin:                       \(bounds.min)
        boundsMax:                       \(bounds.max)
        boundsCenter:                    \(boundsCenterPosition)
        --
        """
    }
}
