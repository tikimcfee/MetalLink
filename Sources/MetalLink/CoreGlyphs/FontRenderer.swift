//
//  FontRenderer.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 5/5/22.
//

import Foundation

public struct FontRenderer {
    public static let shared: FontRenderer = FontRenderer()
    
    public let measuringFont: NSUIFont = MONOSPACE_FONT
    public let renderingFont: NSUIFont = UNIT_FONT
    
    private init() { }
}

public extension FontRenderer {
    func measure(_ text: String) -> (LFloat2, LFloat2) {
        
        let measureSize = text.size(withAttributes: [.font: measuringFont])
        let textSize = LFloat2(measureSize.width.float, measureSize.height.float)
        let textSizeScaled = LFloat2(
            x: textSize.x * Self.SCALE_FACTOR,
            y: textSize.y * Self.SCALE_FACTOR
        )
        return (textSize, textSizeScaled)
    }
    
    func descale(_ size: LFloat2) -> LFloat2 {
        let descaledWidth = size.x / Self.DESCALE_FACTOR
        let descaledHeight = size.y / Self.DESCALE_FACTOR
        return LFloat2(x: descaledWidth, y: descaledHeight)
    }
}

private extension FontRenderer {
#if os(iOS)
    static let FONT_SIZE: Float = 32.0
    static let SCALE_FACTOR: Float = 1.0
    static let DESCALE_FACTOR: Float = 32.0
#else
    static let FONT_SIZE: Float = 32.0
    static let SCALE_FACTOR: Float = 1.0
    static let DESCALE_FACTOR: Float = 32.0
#endif
    
    // A font size warning:
    // I never realized this, but I was using the `WORD_POINT_SIZE` font when making glyphs,
    // and measuring with a sized font... and if you don't do that, you end up with things not
    // working correctly, as the font will take into account all sorts of text measuring stuff.
    // So, we use UNIT_FONT when requesting a text-layer to render, and MONOSPACE_FONT to
    static let MONOSPACE_FONT = NSUIFont.monospacedSystemFont(ofSize: FONT_SIZE.cg, weight: .regular)
    static let UNIT_FONT = NSUIFont.monospacedSystemFont(ofSize: 1.0, weight: .regular)
    
    static let STANDARD_FONT = NSUIFont.systemFont(ofSize: FONT_SIZE.cg, weight: .regular)
    static let STANDARD_UNIT_FONT = NSUIFont.systemFont(ofSize: 1.0, weight: .regular)
}
