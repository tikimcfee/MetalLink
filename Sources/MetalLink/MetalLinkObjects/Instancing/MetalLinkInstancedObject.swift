//
//  MetalLinkInstancedObject.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import MetalKit
import MetalLinkHeaders
//import Algorithms

open class MetalLinkInstancedObject<InstancedNodeType: MetalLinkNode>: MetalLinkNode {
    public let link: MetalLink
    public var mesh: any MetalLinkMesh
    
    private lazy var pipelineState: MTLRenderPipelineState
        = link.pipelineStateLibrary[.Instanced]
    
    private lazy var stencilState: MTLDepthStencilState
        = link.depthStencilStateLibrary[.Less]
    
    private var material = MetalLinkMaterial()
    
    // TODO: Use regular constants for root, not instanced
    public var rootConstants = BasicModelConstants() {
        didSet { rebuildSelf = true }
    }
    
    public var rebuildSelf: Bool = true
    public var rebuildInstances: Bool = false
    public var rootState = State()
    public let instanceState: InstanceState<InstancedNodeType>

    public init(
        _ link: MetalLink,
        mesh: any MetalLinkMesh,
        bufferSize: Int = BackingBufferDefaultSize
    ) throws {
        self.link = link
        self.mesh = mesh
        self.instanceState = try InstanceState(
            link: link,
            bufferSize: bufferSize
        )
        super.init()
    }
    
    open override func update(deltaTime: Float) {
        rootState.time += deltaTime
        updateModelConstants()
        super.update(deltaTime: deltaTime)
    }
    
    open override func enumerateChildren(_ action: (MetalLinkNode) -> Void) {
        
    }
    
    open func performJITInstanceBufferUpdate(_ node: MetalLinkNode) {
        // override to do stuff right before instance buffer updates
    }
}

extension MetalLinkInstancedObject {
    public func setColor(_ color: LFloat4) {
        material.color = color
        material.useMaterialColor = true
    }
}

extension MetalLinkInstancedObject {
    func updateModelConstants() {
        if rebuildSelf {
            rootConstants.modelMatrix = modelMatrix
            rebuildSelf = false
        }
    }
}

protocol DrawPassVertexProvider {
    var vertexID: UUID { get }
    var vertexLength: Int { get }
    var vertexIndex: Int { get }
}

protocol DrawPassConstantsProvider {
    var constantsID: UUID { get }
    var constantsOffset: Int { get }
    var constantsIndex: Int { get }
}


extension MetalLinkInstancedObject: MetalLinkRenderable {
    func doRender(in sdp: inout SafeDrawPass) {
        guard !instanceState.nodes.isEmpty,
              let meshVertexBuffer = mesh.getVertexBuffer()
        else { return }
        
        let constantsBuffer = instanceState.instanceBuffer
        
        // Setup rendering states for next draw pass
        sdp.currentPipeline = pipelineState
        sdp.currentDepthStencil = stencilState
        
        // Set small buffered constants and main mesh buffer
        sdp.setCurrentVertexBuffer(meshVertexBuffer, 0, 0)
        sdp.setCurrentVertexBuffer(constantsBuffer, 0, 2)
                
        // Draw the single instanced glyph mesh (see DIRTY FILTHY HACK for details).
        // Constants need to capture vertex transforms for emoji/nonstandard.
        // OR, use multiple draw calls for sizes (noooo...)
        sdp.renderCommandEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: mesh.vertexCount,
            instanceCount: instanceState.instanceBufferCount
        )
    }
}

enum LinkInstancingError: String, Error {
    case generatorFunctionFailed
}
