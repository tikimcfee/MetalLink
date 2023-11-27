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

/// [ character: [
///     color:
///         color: key
///     ]
/// ]

// I'm a monster
//typealias ForegroundCache = LockingCache<NSUIColor, GlyphCacheKey>
//typealias CompositeCache = LockingCache<NSUIColor, ForegroundCache>
//typealias CharCache = LockingCache<Character, CompositeCache>

typealias ForegroundCache = [NSUIColor: GlyphCacheKey]
typealias CompositeCache = [NSUIColor: ForegroundCache]
typealias CharCache = [Character: CompositeCache]

public struct GlyphCacheKey: Codable, Hashable, Equatable {
    public let source: Character
    public let glyph: String
    
    public let foreground: SerialColor
    public let background: SerialColor
    
    public init(
        source: Character,
        _ foreground: NSUIColor,
        _ background: NSUIColor = NSUIColor.black
    ) {
        self.source = source
        self.glyph = String(source)
        self.foreground = foreground.serializable
        self.background = background.serializable
    }
}

extension Character: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = string.first!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self))
    }
}


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
