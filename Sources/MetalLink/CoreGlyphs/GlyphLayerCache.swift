//
//  The world is too pretty to not know it is.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import BitHandling

typealias ForegroundCache = [NSUIColor: GlyphCacheKey]
typealias CompositeCache = [NSUIColor: ForegroundCache]
typealias CharCache = [Character: CompositeCache]

public struct GlyphCacheKey: Codable, Hashable, Equatable {
    public let glyph: String
    
    public let foreground: SerialColor
    public let background: SerialColor
    
    var unicodeHash: UInt64 {
        glyph.first!.glyphComputeHash
    }
    
    public init(
        source: Character,
        _ foreground: NSUIColor = NSUIColor.white,
        _ background: NSUIColor = NSUIColor.black
    ) {
        self.glyph = String(source)
        self.foreground = foreground.serializable
        self.background = background.serializable
    }
    
    public init(
        _ foreground: SerialColor,
        _ background: SerialColor,
        source: Substring
    ) {
        self.glyph = String(source)
        self.foreground = foreground
        self.background = background
    }
    
    
    enum CodingKeys: Int, CodingKey {
        case glyph = 1
        case foreground = 2
        case background = 3
    }
}


/// [ character: [
///     color:
///         color: key
///     ]
/// ]

// I'm a monster
//typealias ForegroundCache = LockingCache<NSUIColor, GlyphCacheKey>
//typealias CompositeCache = LockingCache<NSUIColor, ForegroundCache>
//typealias CharCache = LockingCache<Character, CompositeCache>

extension GlyphCacheKey {
    static var rootCache = CharCache()
    static var rwlock = LockWrapper()
    
    public static func fromCache(
        source: Character,
        _ foreground: NSUIColor,
        _ background: NSUIColor = NSUIColor.black
    ) -> GlyphCacheKey {
        var updated = false
        rwlock.readLock()
        var compositeCache = rootCache[source, default: {
            updated = true
            return CompositeCache()
        }()]
        var foregroundCache = compositeCache[background, default: {
            updated = true
            return ForegroundCache()
        }()]
        let key = foregroundCache[foreground, default: {
            updated = true
//            print(
//            """
//            glyph |-----------
//            glyph | \(source)
//            glyph | \(foreground.rgba!)
//            glyph | \(background.rgba!)
//            glyph | \(source.unicodeScalars)
//            glyph |-----------
//            """
//            )
            return GlyphCacheKey(
                source: source,
                foreground,
                background
            )
        }()]
        rwlock.unlock()
        
        if updated {
            rwlock.writeLock()
            foregroundCache[foreground] = key
            compositeCache[background] = foregroundCache
            rootCache[source] = compositeCache
            rwlock.unlock()
        }
        
        return key
    }
    
}
