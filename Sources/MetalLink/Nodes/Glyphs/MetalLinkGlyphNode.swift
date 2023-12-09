//
//  LinkGlyph.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/11/22.
//

import MetalKit
import MetalLinkHeaders

public typealias GlyphNode = MetalLinkGlyphNode
public typealias NodeSyntaxID = String
public typealias NodeSet = Set<GlyphNode>
public typealias SortedNodeSet = [GlyphNode]

// TODO: Use a delegate thing
// Point model matrix / size / bounds / etc into a buffer pointer at an index.
// That should mean instant updates into the GPU without computes... I guess..?
// Parenting could work that way too...
public class MetalLinkGlyphNode: MetalLinkObject, QuadSizable {
    public let key: GlyphCacheKey
    public var meta: Meta
    
    public var quad: MetalLinkQuadMesh
    public var node: MetalLinkNode { self }
    
    public override var hasIntrinsicSize: Bool { true }
    
    public override var contentBounds: Bounds {
        Bounds(
            LFloat3(-quad.width / 2.0, -quad.height / 2.0, 0),
            LFloat3( quad.width / 2.0,  quad.height / 2.0, 1)
        ) * scale
    }
    
    public init(
        _ link: MetalLink,
        key: GlyphCacheKey,
        quad: MetalLinkQuadMesh
    ) {
        self.key = key
        self.quad = quad
        self.meta = Meta()
        super.init(link, mesh: quad)
    }
    
    public func setQuadSize(size: LFloat2) {
        guard !quad.initialSizeSet else { return }
        let size = UnitSize.from(size)
        quad.setSize(size)
    }
    
    public func setQuadUnitSize(size: LFloat2) {
        guard !quad.initialSizeSet else { return }
        quad.setSize(size)
    }
}

public extension MetalLinkGlyphNode {
    // Optional meta on nodes; I think I'm shifting to using these as the
    // carrier of truth since I have more control of where they come from.
    // I think SCNNode made it trickier to know what was what. I'm decreasing
    // flexibility and adding cohesion (coupling?). This is basically what I
    // encoded into SCNNode.name. This is more explicit.
    struct Meta {
        public var syntaxID: NodeSyntaxID?
        
        public init(
            syntaxID: String? = nil
        ) {
            self.syntaxID = syntaxID
        }
    }
}

public extension MetalLinkGlyphNode {
    enum GroupType {
        case glyphCollection(instanceID: InstanceIDType)
        case standardGroup
    }
}
