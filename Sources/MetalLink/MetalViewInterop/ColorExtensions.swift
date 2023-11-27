//
//  ColorExtensions.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/29/22.
//

import Foundation

/**
 A tuple of the red, green, blue and alpha components of this NSColor calibrated
 in the RGB color space. Each tuple value is a CGFloat between 0 and 1.
 https://github.com/jeffreymorganio/nscolor-components/blob/master/Sources/NSColor%2BComponents.swift
 https://stackoverflow.com/questions/15682923/convert-nscolor-to-rgb/15682981#15682981
 */
#if os(iOS)
import UIKit
#endif

public struct SerialColor: Codable, Hashable, Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    
    public static let white = SerialColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let black = SerialColor(red: 0, green: 0, blue: 0, alpha: 1)
    
    public var asColor: NSUIColor {
#if os(OSX)
        NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(iOS)
        NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
#endif
    }
}

public extension NSUIColor {
    var serializable: SerialColor {
        guard let data = rgba else { return .white }
        return SerialColor(red: data.red, green: data.green, blue: data.blue, alpha: data.alpha)
    }
    
#if os(OSX)
    var rgba: (red:CGFloat, green:CGFloat, blue:CGFloat, alpha:CGFloat)? {
        if let calibratedColor = usingColorSpace(.genericRGB) {
            var redComponent = CGFloat(0)
            var greenComponent = CGFloat(0)
            var blueComponent = CGFloat(0)
            var alphaComponent = CGFloat(0)
            calibratedColor.getRed(&redComponent,
                                   green: &greenComponent,
                                   blue: &blueComponent,
                                   alpha: &alphaComponent)
            return (redComponent, greenComponent, blueComponent, alphaComponent)
        }
        return nil
    }
#elseif os(iOS)
    var rgba: (red:CGFloat, green:CGFloat, blue:CGFloat, alpha:CGFloat)? {
        var redComponent = CGFloat(0)
        var greenComponent = CGFloat(0)
        var blueComponent = CGFloat(0)
        var alphaComponent = CGFloat(0)
        getRed(&redComponent,
               green: &greenComponent,
               blue: &blueComponent,
               alpha: &alphaComponent)
        return (redComponent, greenComponent, blueComponent, alphaComponent)
    }
#endif
}
