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
    var contentOffset: LFloat3 { get }
    
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
    var contentHalfWidth: Float { BoundsWidth(contentBounds) / 2.0 }
    var contentHalfHeight: Float { BoundsHeight(contentBounds) / 2.0 }
    var contentHalfLength: Float { BoundsLength(contentBounds) / 2.0 }
}

// MARK: - Bounds

public extension Measures {
    var boundsWidth: VectorFloat {
        let currentBounds = bounds
        return BoundsWidth(currentBounds)
    }
    var boundsHeight: VectorFloat {
        let currentBounds = bounds
        return BoundsHeight(currentBounds)
    }
    var boundsLength: VectorFloat {
        let currentBounds = bounds
        return BoundsLength(currentBounds)
    }
    
    var boundsCenterWidth: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.x + BoundsWidth(currentBounds) / 2.0
    }
    var boundsCenterHeight: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.y + BoundsHeight(currentBounds) / 2.0
    }
    var boundsCenterLength: VectorFloat {
        let currentBounds = bounds
        return currentBounds.min.z + BoundsLength(currentBounds) / 2.0
    }
    
    var boundsCenterPosition: LFloat3 {
        let currentBounds = bounds
        let vector = LFloat3(
            x: currentBounds.min.x + BoundsWidth(currentBounds) / 2.0,
            y: currentBounds.min.y + BoundsHeight(currentBounds) / 2.0,
            z: currentBounds.min.z + BoundsLength(currentBounds) / 2.0
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
    public func convertPosition(_ convertTarget: LFloat3, to final: MetalLinkNode?) -> LFloat3 {
        var position: LFloat3 = convertTarget
        var nodeParent = parent
        while !(nodeParent == final || nodeParent == nil) {
            if let nodeMatrix = nodeParent?.modelMatrix {
                let multiplied = matrix_multiply(nodeMatrix, LFloat4(position.x, position.y, position.z, 1))
                position = LFloat3(multiplied.x, multiplied.y, multiplied.z)
            }
            nodeParent = nodeParent?.parent
        }
        
        if let finalMatrix = final?.modelMatrix {
            let multiplied = matrix_multiply(finalMatrix, LFloat4(position.x, position.y, position.z, 1))
            position = LFloat3(multiplied.x, multiplied.y, multiplied.z)
        }
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
    
    // This is so.. not right, but it seems to work? I think it's because `sizeBounds`
    // already converts to parent when building size. So if we use it to compute `worldBounds`,
    // we're counting it multiple times. So.. get the parent, and then *it's* parent's position.
    // That is the starting position for the already transformed bounds. E.g., my bounds are in my
    // parent's coordinate space, and their bounds (position) are in their parent's. If I'm already
    // converted up, then I just need to convert to my parent's position to get the rest of the
    // hiearchy transforms.
    // This is what I'm telling myself to believe it.
    private var _worldPositionForBounds: LFloat3 {
        var finalPosition: LFloat3 = parent?.parent?.position ?? .zero
        var nodeParent = parent?.parent?.parent
        while let parent = nodeParent {
            finalPosition += parent.position
            nodeParent = parent.parent
        }
        return finalPosition
    }
    
    public var worldBounds: Bounds {
        let sizeBounds = sizeBounds
        return Bounds(
            sizeBounds.min + _worldPositionForBounds,
            sizeBounds.max + _worldPositionForBounds
        )
    }
}


public extension Measures {
    func computeSizeInLocalSpace() -> Bounds {
        let computing = BoxComputing()

        for childNode in asNode.children {
            var childSize = childNode.computeBoundingBoxInLocalSpace()
            computing.consumeBounds(childSize)
        }
        
        if hasIntrinsicSize {
            let size = contentBounds
            let offset = contentOffset
            let offsetSize = size + offset + position
            computing.consumeBounds(offsetSize)
        }
        let finalBounds = computing.bounds
        return finalBounds
    }
    
    func computeBoundingBoxInLocalSpace() -> Bounds {
        var size = computeSizeInLocalSpace()
        size.min = convertPosition(size.min, to: parent)
        size.max = convertPosition(size.max, to: parent)
        return size
    }
    
    
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
//            let offset = contentOffset
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
}

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
