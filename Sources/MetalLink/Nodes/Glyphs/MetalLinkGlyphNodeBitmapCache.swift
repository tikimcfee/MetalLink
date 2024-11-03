//
//  MetalLinkNodeBitmapCache.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import Foundation
import BitHandling

public class MetalLinkGlyphNodeBitmapCache: LockingCache<GlyphCacheKey, BitmapImages?> {
    let builder = GlyphBuilder()
    
    public override func make(_ key: Key) -> Value {
        builder.makeBitmaps(key)
    }
}
