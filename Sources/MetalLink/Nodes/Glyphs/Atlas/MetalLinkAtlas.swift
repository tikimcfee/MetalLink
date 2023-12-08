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
    case deserializationError
    case deserializationErrorBuffer
}

public class MetalLinkAtlas {
    private let link: MetalLink
    private let builder: AtlasBuilder
    public let nodeCache: MetalLinkGlyphNodeCache
    public let uvPairCache: TextureUVCache
    public var currentAtlas: MTLTexture { builder.atlasTexture }
    public var currentBuffer: MTLBuffer {
        get { builder.currentGraphemeHashBuffer }
        set { builder.currentGraphemeHashBuffer = newValue }
    }
    
    private var rwLock = LockWrapper()
    
    public init(_ link: MetalLink) throws {
        self.link = link
        let cache = TextureUVCache()
        self.uvPairCache = cache
        self.nodeCache = MetalLinkGlyphNodeCache(link: link)
        self.builder = try AtlasBuilder(
            link,
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
