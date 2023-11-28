//  
//
//  Created on 11/27/23.
//  

import Foundation

public class TextureUVCache: Codable {
    public struct Pair: Codable {
        public let u: LFloat4
        public let v: LFloat4
        public let size: LFloat2
        
        public init(u: LFloat4, v: LFloat4, size: LFloat2) {
            self.u = u
            self.v = v
            self.size = size
        }
    }

    public var map = [GlyphCacheKey: Pair]()
    
    public init() {
        
    }
    
    public subscript(_ key: GlyphCacheKey) -> Pair? {
        get { map[key] }
        set { map[key] = newValue }
    }
}