//
//  MetalLinkInstancedObject+State.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/21/22.
//

import Foundation
import Metal
import BitHandling
import MetalLinkHeaders

public class InstanceState<InstancedNodeType> {
    public let link: MetalLink
        
    public var nodes = ConcurrentArray<InstancedNodeType>()
    public var didSetRoot = false
    
    private let constants: BackingBuffer<InstancedConstants>
    public private(set) var instanceIdNodeLookup = ConcurrentDictionary<InstanceIDType, InstancedNodeType>()
    
    public var instanceBufferCount: Int { constants.currentEndIndex }
    public var instanceBuffer: MTLBuffer { constants.buffer }
    public var rawPointer: UnsafeMutablePointer<InstancedConstants> {
        get { constants.pointer }
        set { constants.pointer = newValue }
    }
    
    public init(
        link: MetalLink,
        bufferSize: Int = BackingBufferDefaultSize
    ) throws {
        self.link = link
        self.constants = try BackingBuffer(
            link: link,
            initialSize: bufferSize
        )
    }
    
    public func indexValid(_ index: Int) -> Bool {
        return index >= 0
            && index < instanceBufferCount
    }
    
    private func makeConstants() throws -> InstancedConstants {
        let newConstants = try constants.createNext {
            $0.instanceID = InstanceCounter.shared.nextGlyphId() // TODO: generic is bad, be specific or change enum thing
        }
        return newConstants
    }
    
    public func makeAndUpdateConstants(_ operation: (inout InstancedConstants) -> Void) throws {
        var newConstants = try makeConstants()
        operation(&newConstants)
        rawPointer[newConstants.arrayIndex] = newConstants
    }
    
    // Appends info and returns last index
    public func appendToState(node newNode: InstancedNodeType) {
        nodes.append(newNode)
    }
    
    public typealias BufferOperator = (
        InstancedNodeType,
        InstancedConstants,
        UnsafeMutablePointer<InstancedConstants>
    ) -> Void
    
    public func zipUpdate(_ nodeUpdateFunction: BufferOperator)  {
//        guard bufferCache.willRebuild else {
//            return
//        }
        
        var pointerCopy = rawPointer
        zip(nodes.values, constants).forEach { node, constant in
            nodeUpdateFunction(node, constant, pointerCopy)
            pointerCopy = pointerCopy.advanced(by: 1)
        }
    }

}
