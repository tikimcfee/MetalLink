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
    public let builder: AtlasBuilder
    public let nodeCache: MetalLinkGlyphNodeCache
    public var currentAtlas: MTLTexture { builder.atlasTexture }
    public var currentBuffer: MTLBuffer {
        get { builder.currentGraphemeHashBuffer }
        set { builder.currentGraphemeHashBuffer = newValue }
    }
    
    private var rwLock = LockWrapper()
    
    public init(
        _ link: MetalLink,
        compute: ConvertCompute
    ) throws {
        self.link = link
        self.nodeCache = MetalLinkGlyphNodeCache(link: link)
        self.builder = try AtlasBuilder(
            link,
            compute: compute
        )
    }
    
    public func save() {
        builder.save()
    }
    
    public func load() {
        builder.load()
    }
    
    public func preload() {
        do {
            try prepareWithGiantRawString()
        } catch {
            print("--- preload failed ---\n", error)
        }
    }
}

extension MetalLinkAtlas {
    
    private func prepareWithGiantRawString() throws {
        print("< ~ > Starting atlas save...")
        
        let sourceString = BIG_CHARACTER_WALL
        var uniqueCharacters = Set<Character>()
        for character in sourceString {
            uniqueCharacters.insert(character)
        }
        let uniqueString = String(Array(uniqueCharacters))
        let uniqueData = uniqueString.data(using: .utf8)!
        
        print("< ~ > Preloading \(uniqueString.count) characters (from \(sourceString.count)), \(uniqueData.count) bytes.")
        
        let compute = builder.compute
        let output = try compute.execute(inputData: uniqueData)
        let (pointer, count) = compute.cast(output)
        
        print("< ~ > Compute complete, starting da loop")
        
        for index in (0..<count) {
            let pointee = pointer[index]
            let hash = pointee.unicodeHash
            guard hash > 0 else { continue; }
            
            // We should always get back 1 character.. that's.. kinda the whole point.
            let unicodeCharacter = pointee.expressedAsString.first!
            
            let key = GlyphCacheKey.fromCache(source: unicodeCharacter, .white)
            addGlyphToAtlasIfMissing(key)
        }
        
        print("< ~ > looped da loop, da save")
        
        save()
        
        print("< ~ > Saved. Cool.")
    }
}
    
public extension MetalLinkAtlas {
    func addGlyphToAtlasIfMissing(_ key: GlyphCacheKey) {
        rwLock.readLock()
        guard builder.cacheRef[key] == nil 
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
