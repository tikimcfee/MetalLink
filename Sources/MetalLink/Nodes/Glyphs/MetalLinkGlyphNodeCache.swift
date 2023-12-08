//
//  MetalLinkGlyphNodeCache.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import Foundation
import Metal
import MetalKit

public class MetalLinkGlyphNodeCache {
    public let link: MetalLink
    
    public let meshCache: MetalLinkGlyphNodeMeshCache
    
    public init(link: MetalLink) {
        self.link = link
        self.meshCache = MetalLinkGlyphNodeMeshCache(link: link)
    }
    
    public func create(_ key: GlyphCacheKey) -> MetalLinkGlyphNode? {
        let mesh = meshCache[key]
        let node = MetalLinkGlyphNode(
            link,
            key: key,
            quad: mesh
        )
        return node
    }
}
