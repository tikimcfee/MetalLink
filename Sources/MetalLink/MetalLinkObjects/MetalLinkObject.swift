//
//  MetalLinkObject.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/7/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit
import MetalLinkHeaders

public class MetalLinkObject: MetalLinkNode, MetalLinkRenderable {
    public let link: MetalLink
    public var mesh: MetalLinkMesh
    
    private lazy var pipelineState: MTLRenderPipelineState
        = link.pipelineStateLibrary[.Basic]
    
    private lazy var stencilState: MTLDepthStencilState
        = link.depthStencilStateLibrary[.Less]
    
    public var state = State()
    public var constants = BasicModelConstants()
    private var material = MetalLinkMaterial()
    
    public init(_ link: MetalLink, mesh: MetalLinkMesh) {
        self.link = link
        self.mesh = mesh
        super.init()
    }
    
    public override func update(deltaTime: Float) {
        super.update(deltaTime: deltaTime)        
        updateModelConstants()
    }
    
    func doRender(in sdp: inout SafeDrawPass) {
        guard let meshVertexBuffer = mesh.getVertexBuffer() else { return }
        
        // Setup rendering states for next draw pass
        sdp.renderCommandEncoder.setRenderPipelineState(pipelineState)
        sdp.renderCommandEncoder.setDepthStencilState(stencilState)
        
        // Set small <4kb buffered constants and main mesh buffer
        sdp.renderCommandEncoder.setVertexBuffer(meshVertexBuffer, offset: 0, index: 0)
        sdp.renderCommandEncoder.setVertexBytes(&constants, length: BasicModelConstants.memStride, index: 4)
        
        // Update fragment shader
        sdp.renderCommandEncoder.setFragmentBytes(&material, length: MetalLinkMaterial.memStride, index: 1)
        applyTextures(&sdp)
        
        // Do the draw
        drawPrimitives(&sdp)
    }
    
    func applyTextures(_ sdp: inout SafeDrawPass) {
        
    }
    
    // Explicitly overridable
    func drawPrimitives(_ sdp: inout SafeDrawPass) {
        sdp.renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertexCount)
    }
}

extension MetalLinkObject {
    public func setColor(_ color: LFloat4) {
        material.color = color
        material.useMaterialColor = true
    }
}

extension MetalLinkObject {
    public func updateModelConstants() {
        // Pull matrix from node position
        constants.modelMatrix = modelMatrix
    }
}

//extension MTLRenderCommandEncoder {
//    func setVertexBytes<T>(_ buffer: [T], index: Int) {
//        buffer.withUnsafeBytes {
//            setVertexBytes($0.baseAddress!, length: $0.count, index: index)
//        }
//    }
//
//    func setFragmentBytes<T>(_ buffer: [T], index: Int) {
//        buffer.withUnsafeBytes {
//            setFragmentBytes($0.baseAddress!, length: $0.count, index: index)
//        }
//    }
//}
//
