//
//  MetalLinkNode+Measures.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/26/22.
//

import Foundation
import Metal

extension MetalLinkNode {
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
    public var _worldPositionForBounds: LFloat3 {
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
        return (
            min: sizeBounds.min + _worldPositionForBounds,
            max: sizeBounds.max + _worldPositionForBounds
        )
    }
}
