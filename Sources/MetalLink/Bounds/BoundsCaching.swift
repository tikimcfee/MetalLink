//
//  SceneKit+BoundsCaching.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 6/13/21.
//

import Foundation
import SceneKit
import BitHandling

//typealias BoundsKey = String
public typealias BoundsKey = MetalLinkNode
public let BoundsZero: Bounds = (min: .zero, max: .zero)

// MARK: Bounds caching
public class BoundsCaching {
    private static var boundsCache = ConcurrentDictionary<BoundsKey, Bounds>()
    
    public static func Clear() {
        boundsCache.removeAll()
    }

    public static func get(_ node: MetalLinkNode) -> Bounds? {
        return boundsCache[node]
    }
    
    public static func Set(_ node: MetalLinkNode, _ bounds: Bounds?) {
        boundsCache[node] = bounds
    }
    
    public static func ClearRoot(_ root: MetalLinkNode) {
        boundsCache[root] = nil
        root.enumerateChildren { node in
            boundsCache[node] = nil
        }
    }
}

public class SizeCaching {
    private static var sizeCache = ConcurrentDictionary<BoundsKey, Bounds>()
    
    public static func Clear() {
        sizeCache.removeAll()
    }

    public static func Get(_ node: MetalLinkNode) -> Bounds? {
        return sizeCache[node]
    }
    
    public static func Set(_ node: MetalLinkNode, _ bounds: Bounds?) {
        sizeCache[node] = bounds
    }
    
    public static func ClearRoot(_ root: MetalLinkNode) {
        sizeCache[root] = nil
        root.enumerateChildren { node in
            sizeCache[node] = nil
        }
    }
}
