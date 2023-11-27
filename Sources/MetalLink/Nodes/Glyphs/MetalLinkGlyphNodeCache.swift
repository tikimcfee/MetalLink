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
    public let textureCache: MetalLinkGlyphTextureCache
    
    public init(link: MetalLink) {
        self.link = link
        self.meshCache = MetalLinkGlyphNodeMeshCache(link: link)
        self.textureCache = MetalLinkGlyphTextureCache(link: link)
    }
    
    public func create(_ key: GlyphCacheKey) -> MetalLinkGlyphNode? {
        do {
//            guard let glyphTexture = textureCache[key]
//            else { throw MetalGlyphError.noTextures }
            
            let mesh = meshCache[key]
            let node = MetalLinkGlyphNode(
                link,
                key: key,
//                texture: ,
                quad: mesh
            )
            
//            node.constants.textureIndex = glyphTexture.textureIndex
            
            return node
        } catch {
            print(error)
            return nil
        }
    }
}
