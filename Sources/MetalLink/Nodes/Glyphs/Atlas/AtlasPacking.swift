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
    
    public init() { }
}

public class VertexRect: AtlasPackable {
    public var x: Int = .zero
    public var y: Int = .zero
    public var width: Int = .zero
    public var height: Int = .zero
    public var wasPacked = false
    
    public init() { }
}

public class AtlasPacking<T: AtlasPackable> {
    struct State: Codable {
        var currentX: T.Number = .zero
        var currentY: T.Number = .zero
        var largestHeightThisRow: T.Number = .zero
    }
    
    let canvasWidth: T.Number
    let canvasHeight: T.Number
    
    private(set) var currentX: T.Number = .zero
    private(set) var currentY: T.Number = .zero
    private var largestHeightThisRow: T.Number = .zero
    
    public init(
        width: T.Number,
        height: T.Number
    ) {
        self.canvasWidth = width
        self.canvasHeight = height
    }
    
    public func packNextRect(_ rect: T) {
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
        rect.wasPacked = true;
    }
    
    func save() -> State {
        State(
            currentX: currentX,
            currentY: currentY,
            largestHeightThisRow: largestHeightThisRow
        )
    }
    
    func load(_ state: State) {
        self.currentX = state.currentX
        self.currentY = state.currentY
        self.largestHeightThisRow = state.largestHeightThisRow
    }
}
