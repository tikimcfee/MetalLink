//
//  GlyphLayer+iOS.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 5/5/22.
//

#if os(iOS)
import Foundation
import CoreServices
import UIKit

public typealias BitmapImages = (
    requested: NSUIImage,
    requestedCG: CGImage,
    template: NSUIImage,
    templateCG: CGImage
)

public extension CALayer {
    func getBitmapImage(
        using key: GlyphCacheKey
    ) -> BitmapImages? {
        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(frame.size, isOpaque, 0)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setFillColor(key.background.cgColor)
        context.fill(frame)
        render(in: context)
        
        let options = NSDictionary(dictionary: [
            :
//            kCGImageDestinationLossyCompressionQuality: 0.0
        ])
        
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()!.cgImage!
        let mutableData = CFDataCreateMutable(nil, 0)!
        let destination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil)!
        CGImageDestinationSetProperties(destination, options)
        CGImageDestinationAddImage(destination, outputImage, nil)
        CGImageDestinationFinalize(destination)
        let source = CGImageSourceCreateWithData(mutableData, nil)!
        let finalImage = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        
        return (
            UIImage(cgImage: finalImage),
            finalImage,
            UIImage(cgImage: finalImage),
            finalImage
        )
    }
}
#endif
