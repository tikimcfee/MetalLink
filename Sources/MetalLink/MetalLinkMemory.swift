//
//  MetalLinkMemory.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/6/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import simd
import MetalLinkHeaders
import MetalKit
import Foundation

public protocol MemoryLayoutSizable {
    static func memSize(of count: Int) -> Int
    static func memStride(of count: Int) -> Int
}

public extension MemoryLayoutSizable {
    static var memSize: Int {
        MemoryLayout<Self>.size
    }
    
    static var memStride: Int {
        MemoryLayout<Self>.stride
    }
}

public extension MemoryLayoutSizable {
    static func memSize(of count: Int) -> Int {
        memSize * count
    }
    
    static func memStride(of count: Int) -> Int {
        memStride * count
    }
}

extension UInt: MemoryLayoutSizable { }
extension UInt32: MemoryLayoutSizable { }
extension UInt64: MemoryLayoutSizable { }
extension LFloat2: MemoryLayoutSizable { }
extension LFloat3: MemoryLayoutSizable { }
extension LFloat4: MemoryLayoutSizable { }
extension Float: MemoryLayoutSizable { }
extension Int: MemoryLayoutSizable { }
extension Int32: MemoryLayoutSizable { }
extension Vertex: MemoryLayoutSizable { }
extension ForceLayoutEdge: MemoryLayoutSizable { }
extension ForceLayoutNode: MemoryLayoutSizable { }
extension GlyphMapKernelAtlasIn: MemoryLayoutSizable { }
extension GlyphMapKernelOut: MemoryLayoutSizable { }

