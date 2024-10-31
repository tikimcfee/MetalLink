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
    public lazy var renderer = Renderer()
    
    public lazy var cachedPointerBounds        = CachedValue(update: { [weak self] in self?.pointerBounds() ?? .zero })
    public override var hasIntrinsicSize: Bool { pointerHasIntrinsicSize() }
    public override var contentBounds: Bounds  { cachedPointerBounds.get() }
    public func setRootMesh()                  { setRootMeshPointer() }
    public func resetCollectionState()         { rebuildInstanceAfterCompute() }
        
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
    // TODO: will I ever try more CPU processing?
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
}

public extension GlyphCollection {
    func createWrappedNode(for glyphID: PickingTextureOutputWrapper) -> MetalLinkGlyphNode? {
        guard glyphID.id >= 0 else {
            // Clear color sets red to `Double.infinity` which comes back to us as a -1.
            // I'm sure there's a perfectly valid and logical reason for that and I have
            // no idea why and I'm too tired to care right now, but I certainly appreciate
            // the fact it works that way. Hooray, we finally have a reasonable 'ignore this'
            // value.
            return nil
        }
        
        let (count, pointer) = instancePointerPair
        guard glyphID.id < count else { return nil }
        
        let instance = pointer[Int(glyphID.id)]
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
        
//        for index in (0..<count) {
//            let instance = pointer[index]
//            guard instance.instanceID == glyphID else { continue }
//            
//            let key = linkAtlas.builder.cacheRef.safeReadUnicodeHash(hash: instance.unicodeHash)
//            guard let key else { return nil }
//            
//            let node = GlyphNode(link, key: key, quad: .init(link))
//            node.position = LFloat3(
//                instance.positionOffset.x,
//                instance.positionOffset.y,
//                instance.positionOffset.z
//            )
//            node.quadSize = instance.textureSize
//            node.instanceConstants = instance
//            node.instanceUpdate = instanceState.updateBufferOnChange
//            node.instanceFetch = {
//                let index = instance.arrayIndex
//                guard self.instanceState.indexValid(index) else { return nil }
//                return self.instanceState.rawPointer[index]
//            }
//            
//            return node
//        }
//        return nil
    }
}

// MARK: - Pointer bounds

/*
 I can compute bounds from pointer which is slower but saves lots of memory.
 I can compute from *nodes* which uses lots more memory and is a bit faster.
 I guess test more and leave both options on the table.
 */
/*
 So this works, but it's a bit slower (from more compute?)
 */

public extension GlyphCollection {
    func pointerHasIntrinsicSize() -> Bool {
        instanceState.constants.endIndex > 0
    }

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
        if let bufferedBounds = instanceState.bufferedBounds {
            cachedPointerBounds.set(bufferedBounds)
        } else {
            cachedPointerBounds.dirty()
        }
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
