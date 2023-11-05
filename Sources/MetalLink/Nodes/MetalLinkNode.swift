//
//  MetalLinkNode.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/7/22.
//

import MetalKit
import Combine

open class MetalLinkNode: Measures {
    
    var flare: SignalFlare?
    var lastSeenFlare: SignalFlare.ID?
    
    public init() {
        
    }
    
//    public lazy var currentModel = CachedMatrix4x4(update: { self.buildModelMatrix() })
    public lazy var currentModel = CachedValue { self.buildModelMatrix() }
    public lazy var cachedBounds = CachedValue { self.computeBoundingBox() }
    public lazy var cachedSize = CachedValue { self.computeSize() }
    
    public lazy var nodeId = UUID().uuidString

    open var parent: MetalLinkNode?
        { didSet {
            rebuildModelMatrix()
        } }
    
    open var children: [MetalLinkNode] = []
        { didSet {
            rebuildModelMatrix()
        } }
    
    // MARK: - Model params
    
    public var position: LFloat3 = .zero
        { didSet {
            rebuildModelMatrix()
        } }
    
    public var scale: LFloat3 = LFloat3(1.0, 1.0, 1.0)
        { didSet {
            rebuildModelMatrix()
        } }
    
    public var rotation: LFloat3 = .zero
        { didSet {
            rebuildModelMatrix()
        } }
    
    // MARK: - Overridable Measures
    
    open var hasIntrinsicSize: Bool { false }
    open var contentSize: LFloat3 { .zero }
    open var contentOffset: LFloat3 { .zero }
    
    // MARK: Bounds / Position
    
    public var bounds: Bounds {
        cachedBounds.get()
    }

    public var rectPos: Bounds {
        cachedSize.get()
    }
    
    public var planeAreaXY: VectorFloat {
        return lengthX * lengthY
    }
    
    public var lengthX: VectorFloat {
        let box = bounds
        return abs(box.max.x - box.min.x)
    }
    
    public var lengthY: VectorFloat {
        let box = bounds
        return abs(box.max.y - box.min.y)
    }
    
    public var lengthZ: VectorFloat {
        let box = bounds
        return abs(box.max.z - box.min.z)
    }
    
    public var centerX: VectorFloat {
        let box = bounds
        return lengthX / 2.0 + box.min.x
    }
    
    public var centerY: VectorFloat {
        let box = bounds
        return lengthY / 2.0 + box.min.y
    }
    
    public var centerZ: VectorFloat {
        let box = bounds
        return lengthZ / 2.0 + box.min.z
    }
    
    public var centerPosition: LFloat3 {
        return LFloat3(x: centerX, y: centerY, z: centerZ)
    }
    
    // MARK: Rendering
    open func rebuildModelMatrix() {
        currentModel.dirty()
        cachedBounds.dirty()
        cachedSize.dirty()
        flare?.fire()
        
//        enumerateChildren {
//            $0.rebuildModelMatrix()
//        }
    }
    
    open func render(in sdp: inout SafeDrawPass) {
        for child in children {
            child.render(in: &sdp)
        }
        doRender(in: &sdp)
    }
    
    open func doRender(in sdp: inout SafeDrawPass) {
        
    }
    
    public func update(deltaTime: Float) {
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
        child.flare = flare ?? {
            let flare = SignalFlare()
            self.flare = flare
            return flare
        }()
    }
    
    public func remove(child: MetalLinkNode) {
        children.removeAll(where: { $0.nodeId == child.nodeId })
        child.parent = nil
        
        // "You're the new man of the house, buddy. Good luck out there."
        let newFlare = SignalFlare()
        child.flare = newFlare
        child.enumerateChildren {
            $0.flare = newFlare
        }
    }
    
    open func enumerateChildren(_ action: (MetalLinkNode) -> Void) {
        for child in children {
            action(child)
            child.enumerateChildren(action)
        }
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
        return currentModel.get()
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
        return matrix
    }
}

//// Make this an extension for a target value because hell yes why double up on objects..
//// Can't believe I used a struct. wut. muh memory.
public class CachedValue<T> {
    public private(set) var value: T
    public private(set) var willUpdate: Bool
    public var update: () -> T
    
    public init(update: @escaping () -> T) {
        self.update = update
        self.willUpdate = true
        self.value = update()
    }
    
    public func dirty() {
        willUpdate = true
    }
    
    public func get() -> T {
        guard willUpdate else { return value }
        willUpdate = false
        value = update()
        return value
    }
}

class SignalFlare: Identifiable {
    var id: UUID = UUID()
    
    func fire() {
        id = UUID()
    }
}
