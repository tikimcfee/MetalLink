//
//  GlyphCollection.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/11/22.
//

import MetalKit
import MetalLinkHeaders
import Combine

// There's some kind of `GlyphCollection` in Foundation that gets picked up sometimes.. need to alias
public typealias MetalLinkGlyphCollection = GlyphCollection

public class GlyphCollection: MetalLinkInstancedObject<MetalLinkGlyphNode> {

    public var linkAtlas: MetalLinkAtlas
    public lazy var renderer = Renderer(collection: self)
    public var enumerateNonInstancedChildren: Bool = false
    
    public override var contentSize: LFloat3 {
        return BoundsSize(rectPos)
    }

    // TODO: See MetalLinkNode info about why this is here and not at the root node.
    // It's basically too many updates.
    private var internalParent: MetalLinkNode?
    public override var parent: MetalLinkNode? {
        get { internalParent }
        set { setNewParent(newValue) }
    }
    
    // Better explanation why this works:
    // Rebuild calls parent's build, which walks up the chain (every time).
    // There needs to be a complete chain from this parent to to whatever is being
    // mutated, or you likely won't see all changes.
    private func setNewParent(_ newParent: MetalLinkNode?) {
        newParent?.bindAsVirtualParentOf(self)
        internalParent = newParent
    }
    
    public init(
        link: MetalLink,
        linkAtlas: MetalLinkAtlas,
        bufferSize: Int = BackingBufferDefaultSize
    ) throws {
        self.linkAtlas = linkAtlas
        try super.init(
            link,
            mesh: link.meshLibrary[.Quad],
            bufferSize: bufferSize
        )
    }
        
    private var _time: Float = 0
    private func time(_ dT: Float) -> Float {
        _time += dT
        return _time
    }
    
    public override func update(deltaTime dT: Float) {
        super.update(deltaTime: dT)
    }
    
    public override func render(in sdp: inout SafeDrawPass) {
        sdp.oncePerPass("glyph-collection-atlas") {
            $0.renderCommandEncoder.setFragmentTexture(
                linkAtlas.currentAtlas, index: 5
            )
        }
        
        super.render(in: &sdp)
    }
    
    public override func enumerateChildren(_ action: (MetalLinkNode) -> Void) {
        if enumerateNonInstancedChildren {
//            enumerateInstanceChildren(action)
            children.forEach(action)
        } else {
            enumerateInstanceChildren(action)
        }
    }
    
    public func enumerateInstanceChildren(_ action: (MetalLinkGlyphNode) -> Void) {
        for instance in instanceState.nodes.values {
            action(instance)
        }
    }
    
    open override func performJITInstanceBufferUpdate(_ node: MetalLinkNode) {
//        node.rotation.x -= 0.0167 * 2
//        node.rotation.y -= 0.0167 * 2
//        node.position.z = cos(time(0.0167) / 500)
    }
}

public extension GlyphCollection {
    subscript(glyphID: InstanceIDType) -> MetalLinkGlyphNode? {
        instanceState.instanceIdNodeLookup[glyphID]
    }
}

public extension MetalLinkInstancedObject
where InstancedNodeType == MetalLinkGlyphNode {
    func updatePointer(
        _ operation: (inout UnsafeMutablePointer<InstancedConstants>) throws -> Void
    ) {
        do {
            try operation(&instanceState.rawPointer)
        } catch {
            print("pointer operation update failed")
            print(error)
        }
    }
    
    func updateConstants(
        for node: InstancedNodeType,
        _ operation: (inout InstancedConstants) throws -> Void
    ) rethrows {
        guard let bufferIndex = node.meta.instanceBufferIndex
        else {
            print("Missing buffer index for [\(node.key.glyph)]: \(node.nodeId)")
            return
        }
        
        guard instanceState.indexValid(bufferIndex)
        else {
            print("Invalid buffer index for \(node.nodeId)")
            return
        }
        
        // This may be unsafe... not sure what happens here with multithreading.
        // Probably very bad things. If there's a crash here, just create a copy
        // and don't be too fancy.
        let pointer = instanceState.rawPointer
        try operation(&pointer[bufferIndex])
    }
}

public extension GlyphCollection {
    func setRootMesh() {
        // ***********************************************************************************
        // TODO: mesh instance hack
        // THIS IS A DIRTY FILTHY HACK
        // The instance only works because the glyphs are all the same size - hooray monospace.
        // The moment there's something that's NOT, we'll get stretching / skewing / breaking.
        // Solving that.. is for next time.
        // Collections of collections per glyph size? Factored down (scaled) / rotated to deduplicate?
        // -- Added a tiny guard to find a mesh that's at least some visible width. This helps
        //    skip newlines or other weird shapes.
        
        // -- Long term idea: the instances can have their own transforms to fit their textures..
        //    how hard would it be to include that in the instance? It already carries the model.
        //    'meshAlignmentTransform' or something akin.
        // ***********************************************************************************
        guard !instanceState.nodes.isEmpty, !instanceState.didSetRoot else {
            return
        }
        
        // TODO: Use safe
        guard let safeMesh = instanceState.nodes.values.first(where: {
            ($0.mesh as? MetalLinkQuadMesh)?.width ?? 0.0 > 0.1 }
        ) else {
            return
        }
        
        instanceState.didSetRoot = true
        mesh = safeMesh.mesh
    }
}
