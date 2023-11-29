//
//  AtlasPacking.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/18/22.
//
//  With thanks to:
//  https://www.david-colson.com/2020/03/10/exploring-rect-packing.html
//

import Foundation

public protocol AtlasPackable: AnyObject {
    associatedtype Number: AdditiveArithmetic & Comparable & Codable
    var x: Number { get set }
    var y: Number { get set }
    var width: Number { get set }
    var height: Number { get set }
    var wasPacked: Bool { get set }
}

public class UVRect: AtlasPackable {
    public var x: Float = .zero
    public var y: Float = .zero
    public var width: Float = .zero
    public var height: Float = .zero
    public var wasPacked = false
}

public class VertexRect: AtlasPackable {
    public var x: Int = .zero
    public var y: Int = .zero
    public var width: Int = .zero
    public var height: Int = .zero
    public var wasPacked = false
}

public protocol AtlasContainer {
    associatedtype Packable: AtlasPackable
    
    var canvasWidth: Packable.Number { get }
    var canvasHeight: Packable.Number { get }
    var currentX: Packable.Number { get set }
    var currentY: Packable.Number { get set }
    var largestHeightThisRow: Packable.Number { get set }
}

public struct AtlasContainerVertex: AtlasContainer, Codable {
    public typealias Packable = VertexRect
    
    public var canvasWidth: Int
    public var canvasHeight: Int

    public var currentX: Int = .zero
    public var currentY: Int = .zero
    public var largestHeightThisRow: Int = .zero
}

public struct AtlasContainerUV: AtlasContainer, Codable {
    public typealias Packable = UVRect
    
    public var canvasWidth: Float
    public var canvasHeight: Float
    
    public var currentX: Float = .zero
    public var currentY: Float = .zero
    public var largestHeightThisRow: Float = .zero
}

public extension AtlasContainer {
    mutating func packNextRect(
        _ rect: Packable
    ) {
        // If this rectangle will go past the width of the image
        // Then loop around to next row, using the largest height from the previous row
        if (currentX + rect.width) > canvasWidth {
            currentY += largestHeightThisRow
            currentX = .zero
            largestHeightThisRow = .zero
        }
        
        // If we go off the bottom edge of the image, then we've failed
        if (currentY + rect.height) > canvasHeight {
            print("No placement for \(rect)")
            return
        }
        
        // This is the position of the rectangle
        rect.x = currentX
        rect.y = currentY
        
        // Move along to the next spot in the row
        currentX += rect.width
        
        // Just saving the largest height in the new row
        if rect.height > largestHeightThisRow {
            largestHeightThisRow = rect.height
        }
        
        // Success!
        rect.wasPacked = true
    }
}
