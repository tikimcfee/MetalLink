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
    
    private lazy var sharedMesh = MetalLinkQuadMesh(link)
    
    public init(link: MetalLink) {
        self.link = link
    }
    
    public func create(_ key: GlyphCacheKey) -> MetalLinkGlyphNode? {
        let mesh = sharedMesh
        let node = MetalLinkGlyphNode(
            link,
            key: key,
            quad: mesh
        )
        return node
    }
}
