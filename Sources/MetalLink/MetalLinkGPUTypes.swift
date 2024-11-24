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

public enum ConstantsFlags: UInt8 {
    case useParent
    case ignoreHover
    case matchesSearch
}

extension SceneConstants: MemoryLayoutSizable { }
extension BasicModelConstants: MemoryLayoutSizable {
    public func getFlag(_ queryFlag: ConstantsFlags) -> Bool {
        getNthBit(flags, bitPosition: queryFlag.rawValue)
    }
    
    mutating public func setFlag(_ queryFlag: ConstantsFlags, _ bit: Bool) {
        flags = modifyNthBit(flags, bitPosition: queryFlag.rawValue, set: bit)
    }
}

func getNthBit(_ value: UInt8, bitPosition: UInt8) -> Bool {
    return (value & (1 << bitPosition)) != 0
}

func modifyNthBit(_ value: UInt8, bitPosition: UInt8, set: Bool) -> UInt8 {
    if set {
        // Set the bit if 'set' is true
        return value | (1 << bitPosition)
    } else {
        // Clear the bit if 'set' is false
        return value & ~(1 << bitPosition)
    }
}

public extension LFloat4 {
    func setAddedColor(
        on instance: inout InstancedConstants?
    ) {
        instance?.addedColorR = UInt8(x * 255)
        instance?.addedColorG = UInt8(y * 255)
        instance?.addedColorB = UInt8(z * 255)
    }
    
    func setMultipliedColor(
        on instance: inout InstancedConstants?
    ) {
        instance?.multipliedColorR = UInt8(x * 255)
        instance?.multipliedColorG = UInt8(y * 255)
        instance?.multipliedColorB = UInt8(z * 255)
    }
}

extension InstancedConstants: MemoryLayoutSizable, BackingIndexed {
    public func getFlag(_ queryFlag: ConstantsFlags) -> Bool {
        getNthBit(flags, bitPosition: queryFlag.rawValue)
    }
    
    mutating public func setFlag(_ queryFlag: ConstantsFlags, _ bit: Bool) {
        flags = modifyNthBit(flags, bitPosition: queryFlag.rawValue, set: bit)
    }
    
    public mutating func reset() {
//        modelMatrix = matrix_identity_float4x4
        textureDescriptorU = .zero
        textureDescriptorV = .zero
        textureSize = .zero
        
        positionOffset = .zero
        
        unicodeHash = .zero
        
        addedColorR = .zero
        addedColorG = .zero
        addedColorB = .zero
        multipliedColorR = UInt8.max
        multipliedColorG = UInt8.max
        multipliedColorB = UInt8.max
        
        bufferIndex = .zero
        setFlag(.useParent, true)
        setFlag(.ignoreHover, false)
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
