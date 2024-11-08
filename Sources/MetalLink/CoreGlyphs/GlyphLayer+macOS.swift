//
//  GlyphLayer+macOS.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 5/5/22.
//

#if os(macOS)
import Foundation
import CoreServices
import AppKit

public struct BitmapImages: Hashable {
    public let requested: NSUIImage
    public let requestedCG: CGImage
    public let template: NSUIImage
    public let templateCG: CGImage
    
    public init(_ requested: NSUIImage,
         _ requestedCG: CGImage,
         _ template: NSUIImage,
         _ templateCG: CGImage) {
        self.requested = requested
        self.requestedCG = requestedCG
        self.template = template
        self.templateCG = templateCG
    }
}

public extension CALayer {
    var cgSize: CGSize {
        CGSize(width: frame.width, height: frame.height)
    }
    
    func getBitmapImage(
        using key: GlyphCacheKey
    ) -> BitmapImages? {
        guard let requested = defaultRepresentation(),
              let template = defaultRepresentation() else {
            return nil
        }
        
        guard let requestedContext = NSGraphicsContext(bitmapImageRep: requested),
              let templateContext = NSGraphicsContext(bitmapImageRep: template) else {
            return nil
        }
        
        backgroundColor = NSUIColor.black.cgColor
        render(in: requestedContext.cgContext)
        
        backgroundColor = NSUIColor(displayP3Red: 0.2, green: 0.7, blue: 0.7, alpha: 0.8).cgColor
        render(in: templateContext.cgContext)
        
        guard let requestedImage = requestedContext.cgContext.makeImage(),
              let templateImage = templateContext.cgContext.makeImage() else {
            return nil
        }
        
        return BitmapImages(
            NSImage(cgImage: requestedImage, size: cgSize),
            requestedImage,
            NSImage(cgImage: templateImage, size: cgSize),
            templateImage
        )
    }
    
    func defaultRepresentation() -> NSBitmapImageRep? {
        return NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(frame.width),
            pixelsHigh: Int(frame.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )
    }
}
#endif
