//
//  File.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/27/22.
//

import Foundation
import BitHandling

// TODO: Make a smarter / safer glyph instance counter
public class InstanceCounter {
    public enum Kind {
        case glyph
        case grid
        case generic
    }
    
    // Starting at 10 to avoid conflict with picking texture color
    // start value (1 when .black)
    public static let startingGeneratedID: InstanceIDType = 10
    public static let shared = InstanceCounter()
    
    private let gridLock = UnfairLock()
    private lazy var gridId = Self.startingGeneratedID
    
    private let glyphLock = UnfairLock()
    private lazy var glyphId = Self.startingGeneratedID
    
    private init() { }
    
    public func nextGridId() -> InstanceIDType {
        gridLock.withAcquiredLock {
            let id = gridId
            gridId += 1
            return id
        }
    }
    
    public func nextGlyphId() -> InstanceIDType {
        glyphLock.withAcquiredLock {
            let id = glyphId
            glyphId += 1
            return id
        }        
    }
}
