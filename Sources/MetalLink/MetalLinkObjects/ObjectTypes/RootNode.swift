//
//  RootNode.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import Combine
import MetalKit
import MetalLinkHeaders

public class RootNode: MetalLinkNode, MetalLinkReader {
    public let camera: DebugCamera
    public var link: MetalLink { camera.link }
    
    public var constants = SceneConstants()
    public var cancellables = Set<AnyCancellable>()
    
    public init(_ camera: DebugCamera) {
        self.camera = camera
        super.init()
    }
    
    public override func update(deltaTime: Float) {
        constants.viewMatrix = camera.viewMatrix
        constants.projectionMatrix = camera.projectionMatrix
        constants.totalGameTime += deltaTime
        camera.interceptor.runCurrentInterceptedState()
        super.update(deltaTime: deltaTime)
    }
    
    public override func render(in sdp: SafeDrawPass) {
        // TODO: This sets global constants, would be nice to get all these things vended or something to avoid settping on buffer indices
        sdp.setCurrentVertexBytes(&constants, SceneConstants.memStride, 1)
        
        super.render(in: sdp)
    }
}
