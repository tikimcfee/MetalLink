//
//  MetalLinkModels.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/8/22.
//

import simd
import Metal
import MetalLinkHeaders

// MARK: - Bridging header extensions

// TODO: Find a nice way to push this into bridging header
public struct Vertex {
    public var position: LFloat3
    public var uvTextureIndex: TextureIndex /* (left, top, width, height) */
    
    public init(
        position: LFloat3,
        uvTextureIndex: TextureIndex
    ) {
        self.position = position
        self.uvTextureIndex = uvTextureIndex
    }
}

extension SceneConstants: MemoryLayoutSizable { }

extension SceneConstants: Equatable {
    public static func == (lhs: SceneConstants, rhs: SceneConstants) -> Bool {
        lhs.totalGameTime == rhs.totalGameTime
        && lhs.projectionMatrix == rhs.projectionMatrix
        && lhs.pointerMatrix == rhs.pointerMatrix
        && lhs.viewMatrix == rhs.viewMatrix
    }
    
}

extension BasicModelConstants: MemoryLayoutSizable { }

extension BasicModelConstants: Equatable {
    public static func == (lhs: BasicModelConstants, rhs: BasicModelConstants) -> Bool {
        lhs.color == rhs.color
        && lhs.modelMatrix == rhs.modelMatrix
        && lhs.pickingId == rhs.pickingId
        && lhs.textureIndex == rhs.textureIndex
    }
}

extension VirtualParentConstants: MemoryLayoutSizable, BackingIndexed {
    public mutating func reset() {
        modelMatrix = matrix_identity_float4x4
        bufferIndex = .zero
//        useParentBuffer = 0
//        parentBufferIndex = 0
    }
}

extension InstancedConstants: MemoryLayoutSizable, BackingIndexed {
    public mutating func reset() {
        modelMatrix = matrix_identity_float4x4
        textureDescriptorU = .zero
        textureDescriptorV = .zero
        instanceID = .zero
        addedColor = .zero
        parentIndex = .zero
        bufferIndex = .zero
    }
}

// MARK: - Extensions

public extension Vertex {
    var positionString: String {
        "(\(position.x), \(position.y), \(position.z))"
    }
}

public extension MetalLinkInstancedObject {
    class State {
        var time: Float = 0
    }
}

public extension MetalLinkObject {
    class State {
        var time: Float = 0
    }
}
