//
//  MetalLinkNode.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/7/22.
//

import MetalKit
import Combine
import MetalLinkHeaders
import simd

open class  MetalLinkNode: Measures {
    public lazy var nodeId = UUID().uuidString
    
    public init() {
        
    }
    
    public var pausedInvalidate: Bool = false
    public var pausedRender: Bool = false
    
    public lazy var cachedSize = CachedValue(update: computeLocalSize)
    public lazy var cachedBounds = CachedValue(update: computeLocalBounds)
    public lazy var currentModel = CachedValue(update: buildModelMatrix)
    public lazy var cachedWorldPosition = CachedValue(update: computeWorldPosition)
    public lazy var cachedWorldBounds = CachedValue(update: computeWorldBounds)
    
    // Whatever just instance everything lolol
    public var localConstants: InstancedConstants = InstancedConstants()
    public var instanceID: InstanceIDType? { instanceConstants?.instanceID }
    public var instanceBufferIndex: Int? { instanceConstants?.arrayIndex }
    public var instanceUpdate: ((InstancedConstants, MetalLinkNode) -> Void)?
    public var instanceFetch: (() -> InstancedConstants?)?
    
    public var instanceConstants: InstancedConstants? {
        get {
            instanceFetch?() ?? localConstants
        }
        set {
            if let newValue {
                if let instanceUpdate {
                    instanceUpdate(newValue, self)
                } else {
                    localConstants = newValue
                }
            }
        }
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
    
    open var worldPosition: LFloat3 {
        get { cachedWorldPosition.get() }
        set { setWorldPosition(newValue) }
    }
    
    public var worldBounds: Bounds {
        cachedWorldBounds.get()
    }
    
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
    
    // Is this... true?
    open var eulerAngles: LFloat3 {
        get { rotation }
        set { rotation = newValue }
    }

    // MARK: - Overridable Measures
    
    open var hasIntrinsicSize: Bool { false }
    open var contentBounds: Bounds { Bounds.zero }
    
    // MARK: Bounds / Position
    
    public var bounds: Bounds {
        return cachedBounds.get()
    }
    
    public var sizeBounds: Bounds {
        return cachedSize.get()
    }
    
    public var planeAreaXY: VectorFloat {
        return lengthX * lengthY
    }
    
    public var lengthX: VectorFloat {
        return bounds.width
    }
    
    public var lengthY: VectorFloat {
        return bounds.height
    }
    
    public var lengthZ: VectorFloat {
        return bounds.length
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
    
    private var willUpdate: Bool {
        return currentModel.willUpdate
        || cachedSize.willUpdate
        || cachedBounds.willUpdate
        || cachedWorldBounds.willUpdate
        || cachedWorldPosition.willUpdate
    }
    
    open func rebuildTreeState() {
        guard !pausedInvalidate else { return }
        
        currentModel.dirty()
        cachedBounds.dirty()
        cachedSize.dirty()
        cachedWorldBounds.dirty()
        cachedWorldPosition.dirty()
        
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
    
    open func render(in sdp: SafeDrawPass) {
        if pausedRender {
            return
        }
        
        for child in children {
            child.render(in: sdp)
        }
        doRender(in: sdp)
    }
    
    open func doRender(in sdp: SafeDrawPass) {
        
    }
    
    open func update(deltaTime: Float) {
        for child in children {
            child.update(deltaTime: deltaTime)
        }
    }
    
    // MARK: Children
    public func collectChildren() -> [[MetalLinkNode]] {
        // No children, skip out
        if children.isEmpty {
            return []
        }
        
        var myChildren = [children]
        for child in children {
            for childCollection in child.collectChildren() {
                // Skip empty sets
                if childCollection.isEmpty {
                    continue
                }
                myChildren.append(childCollection)
            }
        }
        
        // Return full collection
        return myChildren
    }
    
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
    
    public func removeFromParent() {
        if let parent {
            parent.remove(child: self)
        }
    }
}

public extension MetalLinkNode {
    func localFacingTranslate(_ dX: Float = 0, _ dY: Float = 0, _ dZ: Float = 0) {
        localFacingTranslate(
            LFloat3(dX, dY, dZ)
        )
    }
    
    func localFacingTranslate(_ initialDirection: LFloat3) {
        var initialDirection = initialDirection
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
