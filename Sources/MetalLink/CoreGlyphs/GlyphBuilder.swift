//
//  GlyphBuilder.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 5/5/22.
//

import Foundation
import MetalKit

public class GlyphBuilder {
    
    public init() { }
    
    public let fontRenderer = FontRenderer.shared
    
    public func makeBitmaps(_ key: GlyphCacheKey) -> BitmapImages? {
        let textLayer = makeTextLayer(key)
        return textLayer.getBitmapImage(using: key)
    }
    
    public func makeTextLayer(_ key: GlyphCacheKey) -> CATextLayer {
        let safeString = String(key)
        let (_, wordSizeScaled) = fontRenderer.measure(safeString)
        
        // Create and configure text layer
        let textLayer = CATextLayer()
        textLayer.foregroundColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        textLayer.string = safeString
        textLayer.font = fontRenderer.renderingFont
        textLayer.alignmentMode = .left
        textLayer.fontSize = wordSizeScaled.y.cg
        textLayer.frame.size = textLayer.preferredFrameSize()
        
        // Try to get the layer content to update manually. Docs say not to do it;
        // experimentally, it fills the backing content properly and can be used immediately
        textLayer.display()
        
        return textLayer
    }
}
