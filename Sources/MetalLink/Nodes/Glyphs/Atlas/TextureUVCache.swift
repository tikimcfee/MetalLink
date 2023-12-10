//  
//
//  Created on 11/27/23.
//  

import Foundation
import BitHandling

public extension TextureUVCache {
    private static let lock = LockWrapper()
    func safeReadUnicodeHash(hash: UInt64) -> GlyphCacheKey? {
//        Self.lock.readLock()
        let value = unicodeMap[hash]
//        Self.lock.unlock()
        return value
    }
    
    func safeWriteUnicodeHash(hash: UInt64, newValue: GlyphCacheKey) {
        Self.lock.writeLock()
        unicodeMap[hash] = newValue
        Self.lock.unlock()
    }
}

public class TextureUVCache: Codable {
    public var map = [GlyphCacheKey: Pair]()
    
    public var unicodeMap = [UInt64: GlyphCacheKey]()
    
    public init() {
        
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.map = try container.decodeIfPresent([GlyphCacheKey: Pair].self, forKey: .map) ?? [:]
        self.unicodeMap = try container.decodeIfPresent([UInt64: GlyphCacheKey].self, forKey: .unicodeMap) ?? [:]
        
        if unicodeMap.isEmpty && !map.isEmpty {
            map.keys.forEach {
                unicodeMap[$0.unicodeHash] = $0
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(map, forKey: .map)
        try container.encode(unicodeMap, forKey: .unicodeMap)
    }
    
    enum CodingKeys: CodingKey {
        case map
        case unicodeMap
    }
}

public extension TextureUVCache {
    struct Pair: Codable {
        public let u: LFloat4
        public let v: LFloat4
        public let size: LFloat2
        
        public init(u: LFloat4, v: LFloat4, size: LFloat2) {
            self.u = u
            self.v = v
            self.size = size
        }
        
        enum CodingKeys: Int, CodingKey {
            case u = 1
            case v = 2
            case size = 3
        }
    }
}

public extension TextureUVCache {
    subscript(_ key: GlyphCacheKey) -> Pair? {
        get {
            // I truly am a monster p1
            if safeReadUnicodeHash(hash: key.unicodeHash) == nil {
                safeWriteUnicodeHash(hash: key.unicodeHash, newValue: key)
            }
            
            return map[key]
        }
        set {
            map[key] = newValue
            
            // I truly am a monster p2
            if safeReadUnicodeHash(hash: key.unicodeHash) == nil {
                safeWriteUnicodeHash(hash: key.unicodeHash, newValue: key)
            }
        }
    }
}
