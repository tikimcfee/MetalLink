//
//  DescriptorPipelineLibrary.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/7/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit
import BitHandling

public protocol RenderPipelineDescriptor {
    var name: String { get }
    var renderPipelineDescriptor: MTLRenderPipelineDescriptor { get }
}

public enum MetalLinkDescriptorPipeline {
    case BasicPipelineDescriptor
    case Instanced
}

public class RenderPipelineDescriptorLibrary: LockingCache<MetalLinkDescriptorPipeline, RenderPipelineDescriptor> {
    let link: MetalLink
    
    init(link: MetalLink) {
        self.link = link
    }
    
    public override func make(_ key: Key, _ store: inout [Key: Value]) -> Value {
        switch key {
        case .BasicPipelineDescriptor:
            return Basic(link)
        case .Instanced:
            return Instanced(link)
        }
    }
}

// MARK: - Descriptors

public extension RenderPipelineDescriptorLibrary {
    struct Basic: RenderPipelineDescriptor {
        public var name = "Basic RenderPipelineDescriptor"
        public var renderPipelineDescriptor: MTLRenderPipelineDescriptor
        
        init(_ link: MetalLink) {
            let vertexFunction = link.shaderLibrary[.BasicVertex]
            let vertexDescriptor = MetalLinkVertexType.Basic.descriptor
            let fragmentFunction = link.shaderLibrary[.BasicFragment]
            
            self.renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = link.view.colorPixelFormat
            renderPipelineDescriptor.colorAttachments[1].pixelFormat = MetalLinkPickingTexture.Config.pixelFormat // add pixel format to allow both picking and instancing
            renderPipelineDescriptor.colorAttachments[2].pixelFormat = MetalLinkPickingTexture.Config.pixelFormat // add pixel format to
            renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            renderPipelineDescriptor.label = name
        }
    }
}

extension RenderPipelineDescriptorLibrary {
    struct Instanced: RenderPipelineDescriptor {
        public var name = "Instanced RenderPipelineDescriptor"
        public var renderPipelineDescriptor: MTLRenderPipelineDescriptor
        
        init(_ link: MetalLink) {
            let vertexFunction = link.shaderLibrary[.InstancedVertex]
            let vertexDescriptor = MetalLinkVertexType.Instanced.descriptor
            let fragmentFunction = link.shaderLibrary[.InstancedFragment]
            
            self.renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = link.view.colorPixelFormat
            renderPipelineDescriptor.colorAttachments[1].pixelFormat = MetalLinkPickingTexture.Config.pixelFormat
            renderPipelineDescriptor.colorAttachments[2].pixelFormat = MetalLinkPickingTexture.Config.pixelFormat
            renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            renderPipelineDescriptor.label = name
        }
    }
}

func _applyBasicAlphaBlending(to descriptor: MTLRenderPipelineDescriptor, at index: Int) {
    descriptor.colorAttachments[index].isBlendingEnabled = true
    descriptor.colorAttachments[index].rgbBlendOperation = .add
    descriptor.colorAttachments[index].alphaBlendOperation = .add
    descriptor.colorAttachments[index].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[index].sourceAlphaBlendFactor = .sourceAlpha
    descriptor.colorAttachments[index].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[index].destinationAlphaBlendFactor = .oneMinusSourceAlpha
}
