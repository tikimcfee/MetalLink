//
//  MetalLinkInstancedObject.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import MetalKit
import MetalLinkHeaders
//import Algorithms

open class MetalLinkInstancedObject<
    InstanceKey,
    InstancedNodeType: MetalLinkNode
>: MetalLinkNode {
    public let link: MetalLink
    public var mesh: any MetalLinkMesh
    
    private lazy var pipelineState: MTLRenderPipelineState
        = link.pipelineStateLibrary[.Instanced]
    
    private lazy var stencilState: MTLDepthStencilState
        = link.depthStencilStateLibrary[.Less]
    
    private var material = MetalLinkMaterial()
    
    // TODO: Use regular constants for root, not instanced
    public var rootConstants = BasicModelConstants() {
        didSet {
            rebuildSelf = true
        }
    }
    
    public var rebuildSelf: Bool = true
    public var rebuildInstances: Bool = false
    public let instanceState: InstanceState<InstanceKey, InstancedNodeType>

    public init(
        _ link: MetalLink,
        mesh: any MetalLinkMesh,
        bufferSize: Int = BackingBufferDefaultSize,
        instanceBuilder: @escaping (InstanceKey) -> InstancedNodeType?
    ) throws {
        self.link = link
        self.mesh = mesh
        self.instanceState = try InstanceState(
            link: link,
            bufferSize: bufferSize,
            instanceBuilder: instanceBuilder
        )
        super.init()
    }
    
    public init(
        _ link: MetalLink,
        mesh: any MetalLinkMesh,
        instanceState: InstanceState<InstanceKey, InstancedNodeType>
    ) throws {
        self.link = link
        self.mesh = mesh
        self.instanceState = instanceState
        super.init()
    }
    
    open func generateInstance(
        _ key: InstanceKey
    ) -> InstancedNodeType? {
        instanceState.makeNewInstance(key)
    }
    
    open override func update(deltaTime: Float) {
        updateModelConstants()
        super.update(deltaTime: deltaTime)
    }

    open func performJITInstanceBufferUpdate(_ node: MetalLinkNode) {
        // override to do stuff right before instance buffer updates
    }
    
    override public func doRender(in sdp: inout SafeDrawPass) {
        guard instanceState.instanceBufferCount > 0,
              let meshVertexBuffer = mesh.getVertexBuffer()
        else { return }
        
        let constantsBuffer = instanceState.instanceBuffer
        
        // Setup rendering states for next draw pass
        sdp.currentPipeline = pipelineState
        sdp.currentDepthStencil = stencilState
        
        // Set small buffered constants and main mesh buffer
        sdp.setCurrentVertexBuffer(meshVertexBuffer, 0, 0)
        sdp.setCurrentVertexBuffer(constantsBuffer, 0, 2)
        
        // Set our constants so the instancing shader can do the multiplication itself so we don't have to.
        sdp.setCurrentVertexBytes(&rootConstants, BasicModelConstants.memStride, 9)
                
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

extension MetalLinkInstancedObject {
    public func setColor(_ color: LFloat4) {
        material.color = color
        material.useMaterialColor = true
    }
}

extension MetalLinkInstancedObject {
    func updateModelConstants() {
        // TODO: Warning! We need to set the rootConstants matrix so the instances get a fresh update...
        // override rebuild and set there instead? How expensive is it to keep setting the same value?
        if currentModel.willUpdate {
            rootConstants.modelMatrix = modelMatrix
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

enum LinkInstancingError: String, Error {
    case generatorFunctionFailed
}
