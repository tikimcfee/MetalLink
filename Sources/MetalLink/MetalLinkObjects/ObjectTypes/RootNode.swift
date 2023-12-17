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
    
//    public override func update(deltaTime: Float) {
//    
//        super.update(deltaTime: deltaTime)
//    }
    
    public override func render(in sdp: inout SafeDrawPass) {
        constants.viewMatrix = camera.viewMatrix
        constants.projectionMatrix = camera.projectionMatrix
//        constants.totalGameTime += deltaTime
        camera.interceptor.runCurrentInterceptedState()
        
        sdp.setCurrentVertexBytes(&constants, SceneConstants.memStride, 1)
        
        super.render(in: &sdp)
    }
}
