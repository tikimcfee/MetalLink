//
//  MetalLinkCamera.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import MetalKit
import Combine
import simd
import BitHandling

public class DebugCamera: MetalLinkCamera, KeyboardPositionSource, MetalLinkReader {
    public let type: MetalLinkCameraType = .Debug
    public let link: MetalLink
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: -- Matrix
    
    public var worldUp: LFloat3 { LFloat3(0, 1, 0) }
    public var worldRight: LFloat3 { LFloat3(1, 0, 0) }
    public var worldFront: LFloat3 { LFloat3(0, 0, -1) }
    
    private lazy var currentProjection = CachedValue { self.buildProjectionMatrix() }
    private lazy var currentView = CachedValue { self.buildViewMatrix() }
    
    public var position: LFloat3 = .zero { didSet {
        currentProjection.dirty()
        currentView.dirty()
    } }
    
    public var rotation: LFloat3 = .zero { didSet {
        currentProjection.dirty()
        currentView.dirty()
    } }
    
    
    // MARK: -- Controls
    
    public let interceptor = KeyboardInterceptor()
    public var holdingOption: Bool = false
    public var startRotate: Bool = false
    
    public var scrollBounds: Bounds?
    public var notBlockingFromScroll: Bool { scrollLock.isEmpty }
    public var scrollLock: Set<ScrollLock> = [] {
        didSet {
            if scrollLock.isEmpty {
                print("-- removing scroll bounds: \(String(describing: scrollBounds))")
                scrollBounds = nil
            }
        }
    }
    
    public init(link: MetalLink) {
        self.link = link
        bindToLink()
        bindToInterceptor()
    }
}

public extension DebugCamera {
    func moveCameraLocation(_ dX: Float, _ dY: Float, _ dZ: Float) {
        var rotationTransform = simd_mul(
            simd_quatf(angle: rotation.x, axis: X_AXIS),
            simd_quatf(angle: rotation.y, axis: Y_AXIS)
        )
        rotationTransform = simd_mul(
            rotationTransform,
            simd_quatf(angle: rotation.z, axis: Z_AXIS)
        )
        
        var initialDirection = LFloat3(dX, dY, dZ)
        initialDirection = simd_act(rotationTransform.inverse, initialDirection)
        position += initialDirection
        
        if let bounds = scrollBounds {
            position.clamped(min: bounds.min, max: bounds.max)
        }
    }
    
    func unprojectPoint(_ screenPoint: LFloat2) -> LFloat3 {
        let x = screenPoint.x / viewBounds.x * 2 - 1
        let y = screenPoint.y / viewBounds.y * 2 - 1
        
        let clipCoords = LFloat3(x, -y, -1)
        
        let viewProjected = viewMatrix.inverse * LFloat4(clipCoords, 1)
        let viewCoords = LFloat3(viewProjected.x,
                                 viewProjected.y,
                                 viewProjected.z)
        
        let worldProjected = projectionMatrix.inverse * LFloat4(viewCoords, 1)
        let worldCoords = LFloat3(worldProjected.x,
                                  worldProjected.y,
                                  worldProjected.z)
        
        return worldCoords
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
            nearZ: GlobalLiveConfig.Default.cameraNearZ,
            farZ: GlobalLiveConfig.Default.cameraFarZ
        )
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