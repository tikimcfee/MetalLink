//
//  BackingBuffer.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 9/13/22.
//

import Metal

public protocol BackingIndexed {
    var bufferIndex: IndexedBufferType { get set }
    mutating func reset()
}

public extension BackingIndexed {
    var arrayIndex: Int { Int(bufferIndex) }
}

public let BackingBufferDefaultSize = 31_415

public class BackingBuffer<Stored: MemoryLayoutSizable & BackingIndexed> {
    public let link: MetalLink
    public private(set) var buffer: MTLBuffer
    public var pointer: UnsafeMutablePointer<Stored>
    
    public let enlargeMultiplier = 2.01
    
    public var currentBufferSize: Int
    public var currentEndIndex = 0
    
    private var shouldRebuild: Bool {
        currentEndIndex == currentBufferSize
    }
    private var defaultEnlargeNextSize: Int {
        Int(ceil(currentBufferSize.cg * enlargeMultiplier.cg))
    }
    private var enlargeSemaphore = DispatchSemaphore(value: 1)
    private var createSemaphore = DispatchSemaphore(value: 1)
    
    public init(
        link: MetalLink,
        initialSize: Int = BackingBufferDefaultSize
    ) throws {
        self.link = link
        self.currentBufferSize = initialSize
        
        let buffer = try link.makeBuffer(of: Stored.self, count: initialSize)
        self.buffer = buffer
        self.pointer = buffer.boundPointer(as: Stored.self, count: initialSize)
    }
    
    public func remakePointer() {
        self.pointer = buffer.boundPointer(as: Stored.self, count: currentBufferSize)
    }
    
    public func createNext(
        _ withUpdates: ((inout Stored) -> Void)? = nil
    ) throws -> Stored {
        createSemaphore.wait()
        defer { createSemaphore.signal() }
        
        if shouldRebuild {
            try expandBuffer(nextSize: defaultEnlargeNextSize, force: false)
        }
        
        var next = pointer[currentEndIndex]
        next.reset() // Memory is unitialized; call reset to clean up
        
        next.bufferIndex = IndexedBufferType(currentEndIndex)
        withUpdates?(&next)
        
        pointer[currentEndIndex] = next
        
        currentEndIndex += 1
        return next
    }
    
    public func expandBuffer(
        nextSize: Int,
        force: Bool
    ) throws {
        enlargeSemaphore.wait()
        defer { enlargeSemaphore.signal() }
        
        guard nextSize > currentBufferSize else { return }
        
        guard shouldRebuild || force else {
            print("Already enlarged by another consumer; breaking")
            return
        }
        
        let oldSize = currentBufferSize
        print("Enlarging buffer for '\(Stored.self)': \(currentBufferSize) -> \(nextSize)")
        currentBufferSize = nextSize
        
        let copy = pointer
        buffer = try link.copyBuffer(
            from: copy,
            oldCount: oldSize,
            newCount: nextSize
        )
        
        pointer = buffer.boundPointer(as: Stored.self, count: nextSize)
    }
}

extension BackingBuffer: RandomAccessCollection {
    public subscript(position: Int) -> Stored {
        get { pointer[position] }
        set { pointer[position] = newValue }
    }
    
    public var startIndex: Int { 0 }
    public var endIndex: Int { currentEndIndex }
}
