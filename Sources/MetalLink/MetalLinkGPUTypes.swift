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
extension BasicModelConstants: MemoryLayoutSizable { }

extension InstancedConstants: MemoryLayoutSizable, BackingIndexed {
    public mutating func reset() {
        modelMatrix = matrix_identity_float4x4
        textureDescriptorU = .zero
        textureDescriptorV = .zero
        textureSize = .zero
        positionOffset = .zero
        
        unicodeHash = .zero
        
        instanceID = .zero
        addedColor = .zero
        multipliedColor = .one
        bufferIndex = .zero
        useParentMatrix = 1
        ignoreHover = 0
    }
}

public struct ForceLayoutNode {
    // The position of the node in 3D space.
    // This is updated over time based on the node's velocity.
    public var fposition: LFloat3

    // The velocity of the node in 3D space.
    // This is updated over time based on the forces acting on the node.
    public var velocity: LFloat3

    // The force acting on the node in 3D space.
    // This is calculated each frame based on the node's relationships (edges)
    // and interactions with other nodes.
    public var force: LFloat3

    // The mass of the node.
    // In this context, it represents the number of connections (edges) the node has.
    // Nodes with more connections will have a larger mass and will therefore be
    // less affected by forces.
    public var mass: Float
    
    public init(
        fposition: LFloat3,
        velocity: LFloat3,
        force: LFloat3,
        mass: Float
    ) {
        self.fposition = fposition
        self.velocity = velocity
        self.force = force
        self.mass = mass
    }
    
    public static func newZero() -> ForceLayoutNode {
        ForceLayoutNode(fposition: .zero, velocity: .zero, force: .zero, mass: 0)
    }
}

// Edge Struct
public struct ForceLayoutEdge {
    // The first node in the relationship.
    // An edge always connects two nodes.
    public var node1: UInt32

    // The second node in the relationship.
    // An edge always connects two nodes.
    public var node2: UInt32

    // The strength of the relationship between node1 and node2.
    // This is used when calculating the attractive force between the two nodes.
    // Nodes with a stronger relationship will be pulled closer together.
    public var strength: Float
    
    public init(
        node1: UInt32,
        node2: UInt32,
        strength: Float
    ) {
        self.node1 = node1
        self.node2 = node2
        self.strength = strength
    }
}

// MARK: - Helper Extensions

public extension Vertex {
    var positionString: String {
        "(\(position.x), \(position.y), \(position.z))"
    }
}
