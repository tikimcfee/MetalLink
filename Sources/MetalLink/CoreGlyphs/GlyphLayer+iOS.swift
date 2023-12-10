#if os(iOS)
import Foundation
import UIKit
import UniformTypeIdentifiers

public typealias BitmapImages = (
    requested: UIImage,
    requestedCG: CGImage,
    template: UIImage,
    templateCG: CGImage
)

public extension CALayer {
    func getBitmapImage(
        using key: GlyphCacheKey
    ) -> BitmapImages? {
        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(frame.size, isOpaque, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setFillColor(key.background.asColor.cgColor)
        context.fill(frame)
        render(in: context)
        
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let outputImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage,
              let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        // Set any desired properties for the destination
        // For example, to set the compression quality:
        // let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality as CFString: 1.0]
        // CGImageDestinationSetProperties(destination, options as CFDictionary)

        CGImageDestinationAddImage(destination, outputImage, nil)
        CGImageDestinationFinalize(destination)

        guard let source = CGImageSourceCreateWithData(mutableData, nil),
              let finalImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        return (
            UIImage(cgImage: finalImage),
            finalImage,
            UIImage(cgImage: finalImage),
            finalImage
        )
    }
}
#endif
