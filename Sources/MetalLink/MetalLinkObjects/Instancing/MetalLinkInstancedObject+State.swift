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
import MetalLinkResources
import MetalLinkHeaders

public class InstanceState<
    InstanceKey,
    InstancedNodeType: MetalLinkNode
> {
    public typealias BufferOperator = (
        InstancedNodeType,
        InstancedConstants,
        UnsafeMutablePointer<InstancedConstants>
    ) -> Void
    
    public let link: MetalLink
        
    public var nodes = ConcurrentArray<InstancedNodeType>()
    public var didSetRoot = false
    
    public let constants: BackingBuffer<InstancedConstants>
    public private(set) var instanceIdNodeLookup = ConcurrentDictionary<InstanceIDType, InstancedNodeType>()
    
    public var instanceBufferCount: Int { constants.currentEndIndex }
    public var instanceBuffer: MTLBuffer { constants.buffer }
    public var rawPointer: UnsafeMutablePointer<InstancedConstants> {
        get { constants.pointer }
        set { constants.pointer = newValue }
    }
    
    public let instanceBuilder: (InstanceKey) -> InstancedNodeType?
    
    public init(
        link: MetalLink,
        bufferSize: Int = BackingBufferDefaultSize,
        instanceBuilder: @escaping (InstanceKey) -> InstancedNodeType?
    ) throws {
        self.link = link
        self.instanceBuilder = instanceBuilder
        self.constants = try BackingBuffer(
            link: link,
            initialSize: bufferSize
        )
    }
    
    public func indexValid(_ index: Int) -> Bool {
        return index >= 0
            && index < instanceBufferCount
    }
    
    public func makeNewInstance(_ key: InstanceKey) -> InstancedNodeType? {
        guard let instanceTarget = instanceBuilder(key) else {
            return .none
        }
        guard let newInstanceConstants = try? makeNewConstants() else {
            return .none
        }
        
        instanceTarget.instanceConstants = newInstanceConstants
        instanceTarget.instanceUpdate = updateBufferOnChange
        
        instanceIdNodeLookup[newInstanceConstants.instanceID] = instanceTarget
        nodes.append(instanceTarget)
        
        return instanceTarget
    }
    
    // lol get generic'd on
    public func updateBufferOnChange<Node: MetalLinkNode> (
        newConstants: InstancedConstants,
        updated: Node
    ) {
        guard let bufferIndex = updated.instanceBufferIndex else {
            return
        }
        guard indexValid(bufferIndex) else {
            return
        }
        rawPointer[bufferIndex] = newConstants
    }
    
    private func makeNewConstants() throws -> InstancedConstants {
        let newConstants = try constants.createNext {
            // TODO: generic is bad, be specific or change enum thing
            $0.instanceID = InstanceCounter.shared.nextGlyphId()
        }
        
        rawPointer[newConstants.arrayIndex] = newConstants
        return newConstants
    }
}
