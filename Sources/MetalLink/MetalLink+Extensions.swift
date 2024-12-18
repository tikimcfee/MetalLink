//
//  MetalLinkExtensions.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import MetalKit
import MetalLinkHeaders

public extension MTLTexture {
    var simdSize: LFloat2 {
        LFloat2(Float(width), Float(height))
    }
}

public struct UnitSize {
    static func from(_ source: LFloat2) -> LFloat2 {
        let unitWidth = 1 / source.x
        let unitHeight = 1 / source.y
        return LFloat2(min(source.x * unitHeight, 1),
                       min(source.y * unitWidth, 1))
    }
}

public extension LFloat2 {
    var coordString: String { "(\(x), \(y))" }
}

public extension MTLBuffer {
    func boundPointer<T>(as type: T.Type, count: Int) -> UnsafeMutablePointer<T> {
        contents().bindMemory(to: type.self, capacity: count)
    }
    
    func boundPointer<T>(as type: T.Type, count: UInt32) -> UnsafeMutablePointer<T> {
        contents().bindMemory(to: type.self, capacity: Int(count))
    }
}

public extension MetalLink {
    func makeBuffer<T: MemoryLayoutSizable>(
        of type: T.Type,
        count: Int
    ) throws -> MTLBuffer {
        #if os(iOS)
        let mode = MTLResourceOptions.storageModeShared
        #else
        let mode = MTLResourceOptions.storageModeShared
        #endif
        
        guard let buffer = device.makeBuffer(
            length: type.memStride(of: count),
            options: [mode]
        ) else { throw CoreError.noBufferAvailable }
        buffer.label = String(describing: type)
        return buffer
    }
    
    func copyBuffer<T: MemoryLayoutSizable>(
        from source: UnsafeMutablePointer<T>,
        oldCount: Int,
        newCount: Int
    ) throws -> MTLBuffer {
        let newBuffer = try makeBuffer(of: T.self, count: newCount)
        let pointer = newBuffer.boundPointer(as: T.self, count: newCount)
        
        for index in 0..<oldCount {
            pointer[index] = source[index]
        }
        
        // TODO: this throws a mem move exception. doing a manual march seems to work
//        guard let buffer = device.makeBuffer(
//            bytes: source,
//            length: T.memStride(of: count),
//            options: .storageModeManaged
//        ) else { throw CoreError.noBufferAvailable }
        
        newBuffer.label = String(describing: T.self)
        return newBuffer
    }
}


public extension Int {
    var megabytes: String {
        String(
            format: "[%0.5f MB]",
            (Float(self) / 1024.0 / 1024.0)
        )
    }
    
    var megabytesCount: Float {
        Float(self) / 1024.0 / 1024.0
    }
}
