//
//  MetalLinkGlyphNodeMeshCache.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import Foundation
import BitHandling

// TODO: This might go the way of the way of things that go, go
public class MetalLinkGlyphNodeMeshCache: LockingCache<GlyphCacheKey, MetalLinkQuadMesh> {
    let link: MetalLink
    
    init(link: MetalLink) {
        self.link = link
    }
    
    public override func make(_ key: Key, _ store: inout [Key : Value]) -> Value {
        let newMesh = MetalLinkQuadMesh(link)
        return newMesh
    }
}
