//
//  MetalLinkAtlas.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/12/22.
//

import MetalKit
import BitHandling

public enum LinkAtlasError: Error {
    case noTargetAtlasTexture
    case noStateBuilder
}

public class MetalLinkAtlas {
    private let link: MetalLink
    private let builder: AtlasBuilder
    public let nodeCache: MetalLinkGlyphNodeCache
    public let uvPairCache: TextureUVCache
    public var currentAtlas: MTLTexture { builder.atlasTexture }
    
//    private var insertionLock = DispatchSemaphore(value: 1)
    private var rwLock = LockWrapper()
    
    public init(_ link: MetalLink) throws {
        self.link = link
        let cache = TextureUVCache()
        self.uvPairCache = cache
        self.nodeCache = MetalLinkGlyphNodeCache(link: link)
        self.builder = try AtlasBuilder(
            link,
            textureCache: nodeCache.textureCache,
            pairCache: cache
        )
    }
    
    public func save() {
        builder.save()
    }
    
    public func load() {
        builder.load()
    }
}

public extension MetalLinkAtlas {
    func addGlyphToAtlasIfMissing(_ key: GlyphCacheKey) {
//        print("Adding glyph to Atlas: [\(key.glyph)]")
        rwLock.readLock()
        guard uvPairCache[key] == nil 
        else {
            rwLock.unlock()
            return
        }
        rwLock.unlock()
        
        do {
            rwLock.writeLock()
            
            let block = try builder.startAtlasUpdate()
            builder.addGlyph(key, block)
            builder.finishAtlasUpdate(from: block)
            
            rwLock.unlock()
        } catch {
            print(error)
            
            rwLock.unlock()
        }
    }
}

extension MetalLinkAtlas {
    // XCode doesn't handle these well either
//    static let sampleAtlasGlyphs = ["ش"]
}
