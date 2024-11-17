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
    public var didSetRoot = false
    public let constants: BackingBuffer<InstancedConstants>
    
    public var maxRenderCount: Int = GlobalLiveConfig.store.preference.maxInstancesPerGrid
    public var baseRenderIndex: Int = 0
    
    public var minXBuffer: MTLBuffer?
    public var minYBuffer: MTLBuffer?
    public var minZBuffer: MTLBuffer?
    public var bufferedBounds: Bounds? {
        guard let minXBuffer = minXBuffer?.boundPointer(as: Float.self, count: 1),
              let minYBuffer = minYBuffer?.boundPointer(as: Float.self, count: 1),
              let minZBuffer = minZBuffer?.boundPointer(as: Float.self, count: 1),
              let maxXBuffer = maxXBuffer?.boundPointer(as: Float.self, count: 1),
              let maxYBuffer = maxYBuffer?.boundPointer(as: Float.self, count: 1),
              let maxZBuffer = maxZBuffer?.boundPointer(as: Float.self, count: 1)
        else { return nil }
        
        return Bounds(
            LFloat3(
                x: minXBuffer[0],
                y: minYBuffer[0],
                z: minZBuffer[0]
            ),
            LFloat3(
                x: maxXBuffer[0],
                y: maxYBuffer[0],
                z: maxZBuffer[0]
            )
        )
    }
    
    public var maxXBuffer: MTLBuffer?
    public var maxYBuffer: MTLBuffer?
    public var maxZBuffer: MTLBuffer?
    
    public var instanceBufferRange: Range<Int> { (0..<constants.currentEndIndex) }
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
        instanceTarget.instanceFetch = {
            let index = newInstanceConstants.arrayIndex
            guard self.indexValid(index) else { return nil }
            return self.rawPointer[index]
        }
        
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
        let newConstants = try constants.createNext { _ in
            // Now that everything is using 'bufferIndex', we don't need a separated
            // `id` anymore... gulp...
        }
        
        rawPointer[newConstants.arrayIndex] = newConstants
        return newConstants
    }
}
