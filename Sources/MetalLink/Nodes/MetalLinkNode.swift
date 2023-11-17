//
//  MetalLinkNode.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/7/22.
//

import MetalKit
import Combine
import MetalLinkHeaders

open class MetalLinkNode: Measures {
    
    public init() {
        
    }
    
    public var pausedInvalidate: Bool = false
    
    public lazy var cachedSize = CachedValue(update: computeLocalSize)
    public lazy var cachedBounds = CachedValue(update: computeLocalBounds)
    public lazy var currentModel = CachedValue(update: buildModelMatrix)
    
    public lazy var nodeId = UUID().uuidString
    
    // Whatever just instance everything lolol
    public var instanceID: InstanceIDType? { instanceConstants?.instanceID }
    public var instanceBufferIndex: Int? { instanceConstants?.arrayIndex }
    public var instanceUpdate: ((InstancedConstants, MetalLinkNode) -> Void)?
    
    private var didSetInstanceMatrix: Bool = false
    private func pushInstanceUpdate() {
        if let instanceUpdate, let instanceConstants {
            instanceUpdate(instanceConstants, self)
        }
    }
    public var instanceConstants: InstancedConstants? {
        didSet { pushInstanceUpdate() }
    }
    
    open var asNode: MetalLinkNode { self }

    open var parent: MetalLinkNode?
        { didSet {
            rebuildTreeState()
        } }
    
    open var children: [MetalLinkNode] = []
        { didSet {
            rebuildTreeState()
        } }
    
    // MARK: - Model params
    
    open var position: LFloat3 = .zero
        { didSet {
            rebuildTreeState()
        } }
    
    open var scale: LFloat3 = LFloat3(1.0, 1.0, 1.0)
        { didSet {
            rebuildTreeState()
        } }
    
    open var rotation: LFloat3 = .zero
        { didSet {
            rebuildTreeState()
        } }
    
    // MARK: - Overridable Measures
    
    open var hasIntrinsicSize: Bool { false }
    open var contentBounds: Bounds { Bounds.zero }
    
    // MARK: Bounds / Position
    
    public var bounds: Bounds {
        cachedBounds.get()
    }

    public var sizeBounds: Bounds {
        cachedSize.get()
    }
    
    public var planeAreaXY: VectorFloat {
        return lengthX * lengthY
    }
    
    public var lengthX: VectorFloat {
        bounds.width
    }
    
    public var lengthY: VectorFloat {
        bounds.height
    }
    
    public var lengthZ: VectorFloat {
        bounds.length
    }
    
    public var centerX: VectorFloat {
        return bounds.center.x
    }
    
    public var centerY: VectorFloat {
        return bounds.center.y
    }
    
    public var centerZ: VectorFloat {
        return bounds.center.z
    }
    
    public var centerPosition: LFloat3 {
        return bounds.center
    }
    
    // MARK: Rendering
    
    open func rebuildTreeState() {
        guard !pausedInvalidate else { return }
        
        currentModel.dirty()
        cachedBounds.dirty()
        cachedSize.dirty()
        
        for child in children {
            child.rebuildTreeState()
        }
    }
    
    open func rebuildNow() {
        currentModel.updateNow()
        cachedBounds.updateNow()
        cachedSize.updateNow()
        
        for child in children {
            child.rebuildNow()
        }
    }
    
    open func render(in sdp: inout SafeDrawPass) {
        for child in children {
            child.render(in: &sdp)
        }
        doRender(in: &sdp)
    }
    
    open func doRender(in sdp: inout SafeDrawPass) {
        
    }
    
    open func update(deltaTime: Float) {
        children.forEach {
            $0.update(deltaTime: deltaTime)
        }
    }
    
    // MARK: Children
    
    public func add(child: MetalLinkNode) {
        children.append(child)
        if let parent = child.parent {
            print("[\(child.nodeId)] parent already set to [\(parent.nodeId)]")
        }
        child.parent = self
    }
    
    public func remove(child: MetalLinkNode) {
        children.removeAll(where: { $0.nodeId == child.nodeId })
        child.parent = nil
    }
}

extension MetalLinkNode {
    public func localFacingTranslate(_ dX: Float, _ dY: Float, _ dZ: Float) {
        var initialDirection = LFloat3(dX, dY, dZ)
        var rotationTransform = simd_mul(
            simd_quatf(angle: rotation.x, axis: X_AXIS),
            simd_quatf(angle: rotation.y, axis: Y_AXIS)
        )
        rotationTransform = simd_mul(
            rotationTransform,
            simd_quatf(angle: rotation.z, axis: Z_AXIS))
        
        initialDirection = simd_act(rotationTransform.inverse, initialDirection)
        position += initialDirection
    }
}

extension MetalLinkNode: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
    }
    
    public static func == (_ left: MetalLinkNode, _ right: MetalLinkNode) -> Bool {
        return left.nodeId == right.nodeId
    }
}

public extension MetalLinkNode {
    var modelMatrix: matrix_float4x4 {
        currentModel.get()
    }
    
    private func buildModelMatrix() -> matrix_float4x4 {
        // This is expensive.
        var matrix = matrix_identity_float4x4
        matrix.translate(vector: position)
        matrix.rotateAbout(axis: X_AXIS, by: rotation.x)
        matrix.rotateAbout(axis: Y_AXIS, by: rotation.y)
        matrix.rotateAbout(axis: Z_AXIS, by: rotation.z)
        matrix.scale(amount: scale)
        if let parentMatrix = parent?.modelMatrix {
            matrix = matrix_multiply(parentMatrix, matrix)
        }
        instanceConstants?.modelMatrix = matrix
        return matrix
    }
}
