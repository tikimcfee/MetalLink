//
//  MetalLinkGlyphNodeTextureCache.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import MetalKit
import BitHandling

public struct TextureBundle: Equatable {
    public let texture: MTLTexture
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(texture.buffer?.contents())
    }
    
    public static func == (
        _ l: TextureBundle,
        _ r: TextureBundle
    ) -> Bool {
        l.texture.buffer?.contents() == r.texture.buffer?.contents()
    }
}
