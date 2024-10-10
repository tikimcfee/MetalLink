//
//  GlyphCollection.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/11/22.
//

import MetalKit
import MetalLinkHeaders
import BitHandling
import Combine

// There's some kind of `GlyphCollection` in Foundation that gets picked up sometimes.. need to alias
public typealias MetalLinkGlyphCollection = GlyphCollection

final public class GlyphCollection: MetalLinkInstancedObject<
    GlyphCacheKey,
    MetalLinkGlyphNode
> {
    public var linkAtlas: MetalLinkAtlas
    public lazy var renderer = Renderer(collection: self)
    
    /* TODO: Mobile vs. Desktop splt: JUST MAKE LAYOUT BETTER
     So I still haven't done GPU layout because bad brains, but
     I'm figuring out more memory stuff. I can save a bunch of memory
     on mobile without making nodes, and layout will still work.
     Desktop can keep the nodes and be more powerful for now. This
     can stay or go as desired - it's a temporary optimization.
     */
//    #if os(iOS)
    public lazy var cachedPointerBounds = CachedValue(update: pointerBounds)
    public override var hasIntrinsicSize: Bool { pointerHasIntrinsicSize() }
    public override var contentBounds: Bounds  { cachedPointerBounds.get() }
    public func setRootMesh()                  { setRootMeshPointer() }
    public func resetCollectionState()         { rebuildInstanceAfterCompute() }
//    #else
//    public override var hasIntrinsicSize: Bool { nodesHaveIntrinsicSize() }
//    public override var contentBounds: Bounds  { nodeBounds() }
//    public func setRootMesh()                  { setRootMeshNodes() }
//    public func resetCollectionState()         { rebuildInstanceNodesFromState() }
//    #endif
        
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

    public override func render(in sdp: SafeDrawPass) {
        sdp.oncePerPass("glyph-collection-atlas") {
            $0.renderCommandEncoder.setFragmentTexture(
                // MARK: Atlas texture setter
                // Note that this is a computed property that reads whatever the current instance field is,
                // which means that if this is reloaded, it'll reload for all rendered instance collections
                // on the next pass.
                linkAtlas.currentAtlas, index: 5
            )
        }
        
        super.render(in: sdp)
    }
    
}

extension GlyphCollection: MetalLinkReader {
    public var instancePointerPair: (Int, UnsafeMutablePointer<InstancedConstants>) {
        return (instanceCount, instanceState.rawPointer)
    }
    
    public var instanceCount: Int {
        return instanceState.constants.endIndex
    }
    
    public func createInstanceStateCountBuffer() throws -> MTLBuffer {
        let count = instanceCount
        let countBuffer = try createOffsetBuffer(index: UInt32(count))
        countBuffer.label = nodeId
        return countBuffer
    }
}

public extension GlyphCollection {
    subscript(glyphID: InstanceIDType) -> MetalLinkGlyphNode? {
        let (count, pointer) = instancePointerPair
        for index in (0..<count) {
            let instance = pointer[index]
            guard instance.instanceID == glyphID else { continue }
            
            let key = linkAtlas.builder.cacheRef.safeReadUnicodeHash(hash: instance.unicodeHash)
            guard let key else { return nil }
            
            let node = GlyphNode(link, key: key, quad: .init(link))
            node.position = LFloat3(
                instance.positionOffset.x,
                instance.positionOffset.y,
                instance.positionOffset.z
            )
            node.quadSize = instance.textureSize
            node.instanceConstants = instance
            node.instanceUpdate = instanceState.updateBufferOnChange
            node.instanceFetch = {
                let index = instance.arrayIndex
                guard self.instanceState.indexValid(index) else { return nil }
                return self.instanceState.rawPointer[index]
            }
            
            return node
        }
        return nil
    }
}

// MARK: ---- Render Computation Styles ----

/*
 I can compute bounds from pointer which is slower but saves lots of memory.
 I can compute from *nodes* which uses lots more memory and is a bit faster.
 I guess test more and leave both options on the table.
 */

// MARK: - Node bounds
private extension GlyphCollection {
    func nodesHaveIntrinsicSize() -> Bool {
        !instanceState.nodes.isEmpty
    }
    
    func nodeBounds() -> Bounds {
        var totalBounds = Bounds.forBaseComputing
        
//        for node in instanceState.nodes.values {
        for node in instanceState.nodes {
            totalBounds.union(with: node.sizeBounds)
        }
        
        return totalBounds * scale
    }
    
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
                newNode.instanceFetch = {
                    let index = constants.arrayIndex
                    guard self.instanceState.indexValid(index) else { return nil }
                    return self.instanceState.rawPointer[index]
                }
                newNode.setQuadUnitSize(size: constants.textureSize)
//                state.instanceIdNodeLookup[constants.instanceID] = newNode
                state.nodes.append(newNode)
                newNode.parent = self
                
                newNode.pausedInvalidate = false
            }
        }
        pausedInvalidate = false
        
        setRootMesh()
    }
    
    func setRootMeshNodes() {
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
//        guard let safeMesh = instanceState.nodes.values.first(where: {
        guard let safeMesh = instanceState.nodes.first(where: {
            ($0.mesh as? MetalLinkQuadMesh)?.width ?? 0.0 > 0.1 }
        ) else {
            return
        }
        
        instanceState.didSetRoot = true
        mesh = safeMesh.mesh
    }
}

// MARK: - Pointer bounds

/*
 So this works, but it's a bit slower (from more compute?)
 */

public extension GlyphCollection {
    func pointerHasIntrinsicSize() -> Bool {
        instanceState.constants.endIndex > 0
    }
//    
//    func loadFileToInstances(
//        _ fileURL: URL
//    ) {
//        let reader = SplittingFileReader(targetURL: fileURL)
//        let iterator = reader.doSplitNSData(
//            receiver: { line, stopFlag in
//                
//            },
//            lineBreaks: { lineRange, lineBreakFlag in
//                
//            }
//        )
//    }
//    
    func pointerBounds() -> Bounds {
        var totalBounds = Bounds.forBaseComputing
        let pointer = instanceState.constants.pointer
        
        // Use our bounds calculation to update our index... why not..
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
        
        return totalBounds * scale
    }
    
    func rebuildInstanceAfterCompute() {
        // Pointer doesn't need rebuilding, we use the pointer data directly
        cachedPointerBounds.dirty()
        instanceState.constants.remakePointer()
        setRootMeshPointer()
    }
    
    func setRootMeshPointer() {
        guard instanceState.constants.endIndex != 0,
              !instanceState.didSetRoot
        else {
            return
        }
        
        // TODO: Use safe
        
        
        
        let pointer = instanceState.constants.pointer
        let initialSize = instanceState.instanceBufferRange
            .lazy
            .map { pointer[$0].textureSize }
            .filter { $0 != .one && $0.x > 0.1 }
            .first ?? .one
        
        instanceState.didSetRoot = true
        (mesh as? MetalLinkQuadMesh)?.setSize(initialSize)
    }
}
