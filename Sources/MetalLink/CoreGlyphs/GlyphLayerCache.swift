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

public struct GlyphCacheKey: Hashable, Equatable, Codable {
    public let source: Character
    public let glyph: String
    
    public let foreground: NSUIColor
    public let background: NSUIColor
    
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
    
    public init(
        source: Character,
        _ foreground: NSUIColor,
        _ background: NSUIColor = NSUIColor.black
    ) {
        self.source = source
        self.glyph = String(source)
        self.foreground = foreground
        self.background = background
    }
    
    enum Keys: CodingKey {
        case source
        case glyph
        case foreground
        case background
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(glyph, forKey: Keys.glyph)
        
        #if !os(macOS)
        try container.encode(foreground.ciColor.stringRepresentation, forKey: Keys.foreground)
        try container.encode(background.ciColor.stringRepresentation, forKey: Keys.background)
        #else
        try container.encode(foreground.cgColor.components ?? [], forKey: Keys.foreground)
        try container.encode(background.cgColor.components ?? [], forKey: Keys.background)
        #endif
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let glyph = try container.decode(String.self, forKey: Keys.glyph)
        self.glyph = glyph
        self.source = Character(glyph)
        
        #if !os(macOS)
        let foreground = try container.decode(String.self, forKey: Keys.foreground)
        let background = try container.decode(String.self, forKey: Keys.background)
        self.foreground = NSUIColor(ciColor: CIColor(string: foreground))
        self.background = NSUIColor(ciColor: CIColor(string: background))
        #else
        let foreground = try container.decode([CGFloat].self, forKey: Keys.foreground)
        let background = try container.decode([CGFloat].self, forKey: Keys.background)
        if foreground.count == 4 {
            self.foreground = NSUIColor(
                cgColor: CGColor(red: foreground[0], green: foreground[1], blue: foreground[2], alpha: foreground[3])
            )!
        } else {
            self.foreground = NSUIColor.white
        }
        if background.count == 4 {
            self.background = NSUIColor(
                cgColor: CGColor(red: background[0], green: background[1], blue: background[2], alpha: background[3])
            )!
        } else {
            self.background = NSUIColor.black
        }
        #endif
    }
}
