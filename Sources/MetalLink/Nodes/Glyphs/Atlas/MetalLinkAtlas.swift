//
//  MetalLinkAtlas.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/12/22.
//

import MetalKit

public enum LinkAtlasError: Error {
    case noTargetAtlasTexture
    case noStateBuilder
}

public class MetalLinkAtlas {
    private let link: MetalLink
    private let builder: AtlasBuilder
    public let nodeCache: MetalLinkGlyphNodeCache
    public var uvPairCache: TextureUVCache
    public var currentAtlas: MTLTexture { builder.atlasTexture }
    
    private var insertionLock = DispatchSemaphore(value: 1)
    
    public init(_ link: MetalLink) throws {
        self.link = link
        self.uvPairCache = TextureUVCache()
        self.nodeCache = MetalLinkGlyphNodeCache(link: link)
        self.builder = try AtlasBuilder(
            link,
            textureCache: nodeCache.textureCache
        )
    }
    
    public func serialize() {
        builder.serialize()
    }
}

public extension MetalLinkAtlas {
    func addGlyphToAtlasIfMissing(_ key: GlyphCacheKey) {
//        print("Adding glyph to Atlas: [\(key.glyph)]")
        insertionLock.wait()
        defer { insertionLock.signal() }
        guard uvPairCache[key] == nil else { return }
        
        do {
            let block = try builder.startAtlasUpdate()
            builder.addGlyph(key, block)
            (_, uvPairCache) = builder.finishAtlasUpdate(from: block)
        } catch {
            print(error)
        }
    }
}

extension MetalLinkAtlas {
    // XCode doesn't handle these well either
//    static let sampleAtlasGlyphs = ["ش"]
}
