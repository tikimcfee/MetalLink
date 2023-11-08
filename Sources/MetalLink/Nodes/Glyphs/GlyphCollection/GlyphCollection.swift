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

public class GlyphCollection: MetalLinkInstancedObject<
    GlyphCacheKey,
    MetalLinkGlyphNode
> {
    public var linkAtlas: MetalLinkAtlas
    public lazy var renderer = Renderer(collection: self)
    
    public override var contentSize: LFloat3 {
        // TODO: contentSize in GlyphCollection sucks. It uses sizeBounds, but sizeBounds uses computeSise() which uses contentSize, so there's a loop.
        // TODO: Collection can maybe maintain its own size?
        return BoundsSize(sizeBounds)
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
            bufferSize: bufferSize,
            instanceBuilder: { [linkAtlas] key in
                let node = linkAtlas.nodeCache.create(key)
                return node! // may the sins i sow today come back to me tenfold
            }
        )
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
        enumerateInstanceChildren(action)
        for child in children {
            action(child)
        }
    }
    
    public func enumerateInstanceChildren(_ action: (MetalLinkGlyphNode) -> Void) {
        for instance in instanceState.nodes.values {
            action(instance)
        }
    }
    
    open override func performJITInstanceBufferUpdate(_ node: MetalLinkNode) {
        
    }
}

public extension GlyphCollection {
    subscript(glyphID: InstanceIDType) -> MetalLinkGlyphNode? {
        instanceState.instanceIdNodeLookup[glyphID]
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
