//
//  MetalLink.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/6/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import Foundation
import MetalKit
import MetalLinkResources
import MetalLinkHeaders
import Combine

public class MetalLink {
    public let DefaultQueueMaxUnprocessedBuffers = 64
    
    public let view: CustomMTKView
    public let device: MTLDevice
    public let defaultCommandQueue: MTLCommandQueue
    public let defaultLibrary: MTLLibrary
    public let input: DefaultInputReceiver
    
    public lazy var textureLoader: MTKTextureLoader = MTKTextureLoader(device: device)
    
    // TODO: Move these classes into a hierarchy
    // They all use MetalLink._library to fetch, and could be fields instead
    public lazy var meshLibrary = MeshLibrary(self)
    public lazy var shaderLibrary = MetalLinkShaderCache(link: self)
    public lazy var renderPipelineDescriptorLibrary = RenderPipelineDescriptorLibrary(link: self)
    public lazy var pipelineStateLibrary = RenderPipelineStateLibrary(link: self)
    public lazy var depthStencilStateLibrary = DepthStencilStateLibrary(link: self)
    
    // TODO: Make these color indices named to match their descriptor usages
    public lazy var glyphPickingTexture = MetalLinkPickingTexture(link: self, colorIndex: 1)
    public lazy var gridPickingTexture = MetalLinkPickingTexture(link: self, colorIndex: 2)
    
    private lazy var sizeSubject = PassthroughSubject<CGSize, Never>()
    private(set) lazy var sizeSharedUpdates = sizeSubject.share()
    
    public init(view: CustomMTKView) throws {
        self.view = view
        
        guard let device = view.device
        else {
            throw CoreError.noMetalDevice
        }
        
        guard let queue = device.makeCommandQueue(maxCommandBufferCount: DefaultQueueMaxUnprocessedBuffers)
        else {
            throw CoreError.noCommandQueue
        }
        
        guard let library = MetalLinkResources.getDefaultLibrary(from: device)
        else {
            throw CoreError.noDefaultLibrary
        }
        
        self.device = device
        self.defaultCommandQueue = queue
        self.defaultLibrary = library
        self.input = DefaultInputReceiver.shared
    }
}

#if !os(visionOS)
extension MetalLink {
    func onSizeChange(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        sizeSubject.send(size)
    }
}
#endif

// MetalLink reads itself lol
extension MetalLink: MetalLinkReader {
    public var link: MetalLink { self }
}

#if os(iOS)
extension OSEvent {
    var locationInWindow: LFloat2 { LFloat2.zero }
    var deltaY: Float { 0.0 }
    var deltaX: Float { 0.0 }
}

extension Float {
    var float: Float { self }
}
#endif
