//
//  MetalLinkCamera.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import MetalKit
import Combine

public enum MetalLinkCameraType {
    case Debug
}

public protocol MetalLinkCamera: AnyObject {
    var type: MetalLinkCameraType { get }
    var position: LFloat3 { get set }
    var rotation: LFloat3 { get set }
    var projectionMatrix: matrix_float4x4 { get }
    
    var worldUp: LFloat3 { get }
    var worldRight: LFloat3 { get }
    var worldFront: LFloat3 { get }
    
    func moveCameraLocation(_ dX: Float, _ dY: Float, _ dZ: Float)
}

public extension MetalLinkCamera {
    func moveCameraLocation(_ delta: LFloat3) {
        moveCameraLocation(delta.x, delta.y, delta.z)
    }
}

public class DebugCamera: MetalLinkCamera, KeyboardPositionSource, MetalLinkReader {
    public let type: MetalLinkCameraType = .Debug
    
    private lazy var currentProjection = CachedMatrix4x4(update: self.buildProjectionMatrix)
    private lazy var currentView = CachedMatrix4x4(update: self.buildViewMatrix)
    
    public var position: LFloat3 = .zero { didSet {
        currentProjection.dirty()
        currentView.dirty()
    } }
    
    public var rotation: LFloat3 = .zero { didSet {
        currentProjection.dirty()
        currentView.dirty()
    } }
    
    public var worldUp: LFloat3 { LFloat3(0, 1, 0) }
    public var worldRight: LFloat3 { LFloat3(1, 0, 0) }
    public var worldFront: LFloat3 { LFloat3(0, 0, -1) }
    
    public let link: MetalLink
    public let interceptor = KeyboardInterceptor()
    private var cancellables = Set<AnyCancellable>()
    
    public enum ScrollLock: String, CaseIterable, Identifiable, Hashable {
        public var id: Self { self }
        case horizontal
        case vertical
        case transverse
    }
    public var holdingOption: Bool = false
    public var startRotate: Bool = false
    
    public var scrollLock: Set<ScrollLock> = [] {
        didSet {
            if scrollLock.isEmpty {
                print("-- removing scroll bounds: \(String(describing: scrollBounds))")
                scrollBounds = nil
            }
        }
    }
    
    public var scrollBounds: Bounds?
    
    public var notBlockingFromScroll: Bool { scrollLock.isEmpty }
    
    public init(link: MetalLink) {
        self.link = link
        bindToLink()
        bindToInterceptor()
    }
    
    public func bindToLink() {
        link.input.sharedKeyEvent.sink { event in
            self.interceptor.onNewKeyEvent(event)
        }.store(in: &cancellables)
        
        link.input.sharedMouseDown.sink { event in
            guard self.notBlockingFromScroll else { return }
            
            print("mouse down")
            self.startRotate = true
        }.store(in: &cancellables)
        
        link.input.sharedMouseUp.sink { event in
            guard self.notBlockingFromScroll else { return }
            
            print("mouse up")
            
            self.startRotate = false
        }.store(in: &cancellables)
        
        #if os(macOS)
        link.input.sharedScroll.sink { event in
            let (horizontalLock, verticalLock, transverseLock) = (
                self.scrollLock.contains(.horizontal),
                self.scrollLock.contains(.vertical),
                self.scrollLock.contains(.transverse)
            )
            
            let sensitivity: Float = default_MovementSpeed
            let sensitivityModified = default_ModifiedMovementSpeed
            
            let speedModified = self.interceptor.state.currentModifiers.contains(.shift)
            let inOutModifier = self.interceptor.state.currentModifiers.contains(.option)
            let multiplier = speedModified ? sensitivityModified : sensitivity
            
            var dX: Float {
                let final = -event.scrollingDeltaX.float * multiplier
                return final
            }
            var dY: Float {
                let final = inOutModifier ? 0 : event.scrollingDeltaY.float * multiplier
                return final
            }
            var dZ: Float {
                let final = inOutModifier ? -event.scrollingDeltaY.float * multiplier : 0
                return final
            }
            
            let delta = LFloat3(
                horizontalLock ? 0.0 : dX,
                verticalLock ? 0.0 : dY,
                transverseLock ? 0.0 : dZ
            )
            
//            print("--")
//            print("camera: ", self.position)
//            print("delta: ", delta)
//            print("sbounds: ", self.scrollBounds.map { "\($0.min), \($0.max)" } ?? "none" )
            
            self.interceptor.positions.travelOffset = delta
        }.store(in: &cancellables)
        #endif
        
        link.input.sharedMouse.sink { event in
            guard self.startRotate else { return }
            
            
            self.interceptor.positions.rotationDelta.y = event.deltaX.float / 5
            self.interceptor.positions.rotationDelta.x = event.deltaY.float / 5
            self.scrollBounds = nil
        }.store(in: &cancellables)
    }
    
    public func bindToInterceptor() {
        interceptor.positionSource = self
        
        interceptor.positions.$travelOffset.sink { total in
            var total = total
            if self.scrollLock.contains(.horizontal) { total.x = 0 }
            if self.scrollLock.contains(.vertical)   { total.y = 0 }
            if self.scrollLock.contains(.transverse) { total.z = 0 }
            
            self.moveCameraLocation(total / 100)
        }.store(in: &cancellables)
        
        interceptor.positions.$rotationDelta.sink { total in
            guard self.notBlockingFromScroll else { return }
            
            self.rotation += (total / 100)
        }.store(in: &cancellables)
    }
}

public extension DebugCamera {
    func moveCameraLocation(_ dX: Float, _ dY: Float, _ dZ: Float) {
        var initialDirection = LFloat3(dX, dY, dZ)
        var rotationTransform = simd_mul(
            simd_quatf(angle: rotation.x, axis: X_AXIS),
            simd_quatf(angle: rotation.y, axis: Y_AXIS)
        )
        rotationTransform = simd_mul(
            rotationTransform,
            simd_quatf(angle: rotation.z, axis: Z_AXIS)
        )
        initialDirection = simd_act(rotationTransform.inverse, initialDirection)
        position += initialDirection
        
        // This is not the way to do bounds, and I think it's because `worldPosition` and `worldBounds` are broken. Again <3
        if let bounds = scrollBounds {
            if !(bounds.min.x + 32...bounds.max.x).contains(position.x) {
                position.x = max(bounds.min.x + 32, min(position.x, bounds.max.x))
            }
            if !(bounds.min.y - 10...bounds.max.y).contains(position.y) {
                position.y = max(bounds.min.y - 10, min(position.y, bounds.max.y))
            }
            if !(bounds.min.z + 5...bounds.max.z + 100).contains(position.z) {
                position.z = max(bounds.min.z + 5, min(position.z, bounds.max.z + 100))
            }
        }
    }
}

public extension DebugCamera {
    var projectionMatrix: matrix_float4x4 {
        currentProjection.get()
    }
    
    var viewMatrix: matrix_float4x4 {
        currentView.get()
    }
    
    private func buildProjectionMatrix() -> matrix_float4x4 {
        let matrix = matrix_float4x4.init(
            perspectiveProjectionFov: Float.pi / 3.0,
            aspectRatio: viewAspectRatio,
            nearZ: 0.1,
            farZ: 5000
        )
//        matrix.rotateAbout(axis: X_AXIS, by: rotation.x)
//        matrix.rotateAbout(axis: Y_AXIS, by: rotation.y)
//        matrix.rotateAbout(axis: Z_AXIS, by: rotation.z)
        return matrix
    }
    
    private func buildViewMatrix() -> matrix_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.rotateAbout(axis: X_AXIS, by: rotation.x)
        matrix.rotateAbout(axis: Y_AXIS, by: rotation.y)
        matrix.rotateAbout(axis: Z_AXIS, by: rotation.z)
        matrix.translate(vector: -position)
        return matrix
    }
}
