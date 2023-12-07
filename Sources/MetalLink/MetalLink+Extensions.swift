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

extension GraphemeStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case SINGLE: return "single"
        case START: return "start"
        case MIDDLE: return "middle"
        case END: return "end"
        default: return "unknown"
        }
    }
    
    var isSingle: Bool { self == SINGLE }
    var isStart: Bool { self == START }
    var isMiddle: Bool { self == MIDDLE }
    var isEnd: Bool { self == END }
}

extension GraphemeCategory: CustomStringConvertible {
    public var description: String {
        switch self {
        case utf32GlyphSingle: return "single character"
        case utf32GlyphEmojiPrefix: return "emoji group prefix"
        case utf32GlyphTag: return "glyph tag"
        case utf32GlyphEmojiSingle: return "emoji single prefix"
        case utf32GlyphData: return "_data"
        default: return "unknown"
        }
    }
    
    var isSingleGlyph: Bool { self == utf32GlyphSingle }
    var isGlyphPrefix: Bool { self == utf32GlyphEmojiPrefix }
    var isGlyphTag: Bool { self == utf32GlyphTag }
    var isSingleEmoji: Bool { self == utf32GlyphEmojiSingle }
    var isData: Bool { self == utf32GlyphData }
}

public extension GlyphMapKernelOut {
    var expressedAsString: String {
        String(
            String.UnicodeScalarView(
                allSequentialScalars.compactMap {
                    UnicodeScalar($0)
                }
            )
        )
    }
    
    var allSequentialScalars: [UInt32] {
        let scalars = [
         unicodeSlot1,
         unicodeSlot2,
         unicodeSlot3,
         unicodeSlot4,
         unicodeSlot5,
         unicodeSlot6,
         unicodeSlot7,
         unicodeSlot8,
         unicodeSlot9,
         unicodeSlot10,
        ]
        .filter { $0 != .zero }
        
        return scalars
    }
}
