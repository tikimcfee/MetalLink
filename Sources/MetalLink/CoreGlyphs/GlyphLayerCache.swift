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

public typealias GlyphCacheKey = Character

extension GlyphCacheKey: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self))
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = (try container.decode(String.self)).first!
    }
}
