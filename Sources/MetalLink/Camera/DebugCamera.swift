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
    
    public let positionStream = PassthroughSubject<LFloat3, Never>()
    public let rotationSream = PassthroughSubject<LFloat3, Never>()
    
    public var position: LFloat3 = .zero {
        didSet {
            currentProjection.dirty()
            currentView.dirty()
            positionStream.send(position)
        }
    }
    
    public var rotation: LFloat3 = .zero { 
        didSet {
            currentProjection.dirty()
            currentView.dirty()
            rotationSream.send(rotation)
        }
    }
    
    public var nearClipPlane: Float {
        return GlobalLiveConfig.Default.cameraNearZ
    }
    
    public var farClipPlane: Float {
        return GlobalLiveConfig.Default.cameraFarZ
    }
    
    public var fov: Float {
        return GlobalLiveConfig.Default.cameraFieldOfView
    }
    
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
    @discardableResult
    func updating(_ camera: (DebugCamera) -> Void) -> Self {
        camera(self)
        return self
    }
    
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
            position.clampTo(min: bounds.min, max: bounds.max)
        }
    }
    
    func projectPoint(_ point: LFloat3) -> LFloat3 {
        let viewMatrix = viewMatrix
        let projectionMatrix = projectionMatrix
        let point4 = LFloat4(point.x, point.y, point.z, 1)
        
        // Transform the point by the view matrix, then by the projection matrix
        let viewTransformed = viewMatrix * point4
        let projectionTransformed = projectionMatrix * viewTransformed
        
        // Perform perspective division to get normalized device coordinates
        let clipSpacePosition = projectionTransformed / projectionTransformed.w
        
        // Map from [-1, 1] (clip space) to [0, 1] (normalized device coordinates)
        let ndc = (clipSpacePosition + 1) / 2
        
        // The depth is in the z component of the normalized device coordinates
        return LFloat3(ndc.x, ndc.y, ndc.z)
    }

//    func unprojectPoint(_ screenPoint: LFloat2, worldDepth: Float) -> LFloat3 {
//        // Convert screen point to normalized device coordinates (NDC)
//        let xNDC = (screenPoint.x / viewBounds.x) * 2 - 1
//        let yNDC = 1 - (screenPoint.y / viewBounds.y) * 2
//
//        // Convert world depth to a depth value in view space using the camera's view matrix
//        let worldPoint = LFloat3(0, 0, -worldDepth) // Assuming worldDepth is along the camera's forward axis
//        let viewSpacePoint = (viewMatrix * LFloat4(worldPoint, 1)).z
//
//        // Use the view space depth for unprojection
//        let zNDC = (viewSpacePoint - nearClipPlane) / (farClipPlane - nearClipPlane) // Map to NDC depth
//
//        // Unproject from NDC to world space
//        let clipCoords = LFloat4(xNDC, yNDC, zNDC, 1.0)
//        let invProjMatrix = projectionMatrix.inverse
//        let invViewMatrix = viewMatrix.inverse
//        let worldCoords = invViewMatrix * invProjMatrix * clipCoords
//        let worldCoordsNormalized = LFloat3(xyzSource: worldCoords) / worldCoords.w
//        
//        return worldCoordsNormalized
//    }
    
    func unprojectPoint(_ screenPoint: LFloat2, worldDepth: Float) -> LFloat3 {
        // Convert screen coordinates to NDC
        let xNDC = (2.0 * screenPoint.x) / viewBounds.x - 1.0
        let yNDC = 1.0 - (2.0 * screenPoint.y) / viewBounds.y

        // Create clip space position at z = -1 (near plane)
        let nearPoint = LFloat4(xNDC, yNDC, -1.0, 1.0)
        // Create clip space position at z = 1 (far plane)
        let farPoint = LFloat4(xNDC, yNDC, 1.0, 1.0)

        // Transform to view space
        let invProjectionMatrix = projectionMatrix.inverse
        let nearViewSpace = invProjectionMatrix * nearPoint
        let farViewSpace = invProjectionMatrix * farPoint

        // Perspective divide
        let nearWorldSpace = (nearViewSpace / nearViewSpace.w).xyz
        let farWorldSpace = (farViewSpace / farViewSpace.w).xyz

        // Compute the ray direction
        let rayDirection = normalize(farWorldSpace - nearWorldSpace)

        // Compute the intersection with the plane at planeDepth
        let t = (worldDepth - position.z) / rayDirection.z
        let intersectionPoint = position + rayDirection * t

        return intersectionPoint
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
            perspectiveProjectionFov: fov,
            aspectRatio: viewAspectRatio,
            nearZ: nearClipPlane,
            farZ: farClipPlane
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
