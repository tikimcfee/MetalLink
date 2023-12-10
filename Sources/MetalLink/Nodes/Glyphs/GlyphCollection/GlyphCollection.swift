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

final public class GlyphCollection: MetalLinkInstancedObject<
    GlyphCacheKey,
    MetalLinkGlyphNode
> {
    public var linkAtlas: MetalLinkAtlas
    public lazy var renderer = Renderer(collection: self)
    
    
    // TODO: IT'S SO MUCH FASTER!!
    /*
     So intrinsic size is only directly computed in a few cases, and importantly,
     it's mostly during `computeSize` and `computeBoundingBox`. 
     */
    public override var hasIntrinsicSize: Bool {
        !instanceState.nodes.isEmpty
    }
    
    public override var contentBounds: Bounds {
        var totalBounds = Bounds.forBaseComputing
        for node in instanceState.nodes.values {
            totalBounds.union(with: node.sizeBounds)
        }
        return totalBounds * scale
        
        // TODO: So this works, but it's a bit slower, likely from offset creation...
//        return pointerBounds() * scale
    }
    
    private func pointerBounds() -> Bounds {
        var totalBounds = Bounds.forBaseComputing
        let pointer = instanceState.constants.pointer
        for index in instanceState.instanceBufferRange {
            let constants = pointer[index]
            let size = constants.textureSize
            var sizeBounds = Bounds(
                LFloat3(-size.x / 2.0, -size.y / 2.0, 0),
                LFloat3( size.x / 2.0,  size.y / 2.0, 1)
            )
            sizeBounds = sizeBounds + LFloat3(constants.positionOffset.x,
                                              constants.positionOffset.y,
                                              constants.positionOffset.z)
            totalBounds.union(with: sizeBounds)
        }
        return totalBounds
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
                linkAtlas.nodeCache.create(key)
            }
        )
    }
    
    public init(
        link: MetalLink,
        linkAtlas: MetalLinkAtlas,
        instanceState: InstanceState<GlyphCacheKey, MetalLinkGlyphNode>
    ) throws {
        self.linkAtlas = linkAtlas
        try super.init(
            link,
            mesh: link.meshLibrary[.Quad],
            instanceState: instanceState
        )
    }

    public override func render(in sdp: inout SafeDrawPass) {
        sdp.oncePerPass("glyph-collection-atlas") {
            $0.renderCommandEncoder.setFragmentTexture(
                // MARK: Atlas texture setter
                // Note that this is a computed property that reads whatever the current instance field is,
                // which means that if this is reloaded, it'll reload for all rendered instance collections
                // on the next pass.
                linkAtlas.currentAtlas, index: 5
            )
        }
        
        super.render(in: &sdp)
    }
    
}

public extension GlyphCollection {
    subscript(glyphID: InstanceIDType) -> MetalLinkGlyphNode? {
        instanceState.instanceIdNodeLookup[glyphID]
    }
}

// MARK: --- Compute Helpers

public extension GlyphCollection {
    func rebuildInstanceNodesFromState() {
        // TODO: This part sucks... I need to get rid of the `GlyphNode` abstraction I think.
        // It's nice that I can interact with it like regular Nodes, but it means I have to
        // create all those instances, which sorta undoes a lot of the speedups.
        // Also had the idea to tweak it so it's a still a node, but can only be initialized
        // around a source buffer, and it can end up reading / writing directly to it kinda
        // like it does now.. maybe even some kind of delegating protocol that's like:
        //
        // `node.renderDelegate = <something>`
        // .. and the render delegate could be a function or a true protocol handler that,
        // maybe just given a node or a specific index, can reach into the buffer to create
        // a facade wrapper just to do updates. That way the objects can still masquerade, but
        // all the gnarly mapping is done behind the scenes. It kinda does that now, but only through
        // the `generateInstance` flow, so...
        
        let state = instanceState
        let nodeCache = linkAtlas.nodeCache
        let glyphCache = linkAtlas.builder.cacheRef
        
        state.constants.remakePointer()
        let constantsPointer = state.constants.pointer
        let count = state.instanceBufferCount
        
        pausedInvalidate = true
        for index in (0..<count) {
            let constants = constantsPointer[index] // this should match...
            guard constants.unicodeHash > 0 else {
                continue
            }
            
            if let cacheKey = glyphCache.safeReadUnicodeHash(hash: constants.unicodeHash),
               let newNode = nodeCache.create(cacheKey)
            {
                newNode.pausedInvalidate = true
                
                newNode.instanceConstants = constants
                newNode.position = LFloat3(constants.positionOffset.x,
                                           constants.positionOffset.y,
                                           constants.positionOffset.z)
                newNode.instanceUpdate = state.updateBufferOnChange
                newNode.setQuadUnitSize(size: constants.textureSize)
                state.instanceIdNodeLookup[constants.instanceID] = newNode
                state.nodes.append(newNode)
                newNode.parent = self
                
                newNode.pausedInvalidate = false
            }
        }
        pausedInvalidate = false
        
        setRootMesh()
    }
    
    func setRootMeshPointer() {
        guard instanceState.constants.endIndex != 0,
              !instanceState.didSetRoot
        else {
            return
        }
        
        // TODO: Use safe
        let pointer = instanceState.constants.pointer
        guard let firstIndex = instanceState.instanceBufferRange.first(where: { index in
            pointer[index].textureSize.x > 0.1
        }) else {
            return
        }
        let firstSize = pointer[firstIndex].textureSize
        
        instanceState.didSetRoot = true
        let newMesh = MetalLinkQuadMesh(link)
        newMesh.setSize(firstSize)
        
        mesh = newMesh
    }
    
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
