//
//  LinkGlyph.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/11/22.
//

import MetalKit
import MetalLinkHeaders

public typealias GlyphNode = MetalLinkGlyphNode

public class MetalLinkGlyphNode: MetalLinkObject, QuadSizable {
    public let key: GlyphCacheKey
    public let texture: MTLTexture
    public var meta: Meta
    
    public var quad: MetalLinkQuadMesh
    public var node: MetalLinkNode { self }
    
    public override var hasIntrinsicSize: Bool { true }
    
    public override var contentSize: LFloat3 {
        LFloat3(quad.width, quad.height, 1)
    }
    
    public override var contentOffset: LFloat3 {
        LFloat3(-quad.width / 2.0, quad.height / 2.0, 0)
    }
    
    public init(_ link: MetalLink,
         key: GlyphCacheKey,
         texture: MTLTexture,
         quad: MetalLinkQuadMesh) {
        self.key = key
        self.texture = texture
        self.quad = quad
        self.meta = Meta()
        super.init(link, mesh: quad)
        setQuadSize()
    }
    
    public func setQuadSize() {
        guard !quad.initialSizeSet else { return }
        let size = UnitSize.from(texture.simdSize)
        quad.setSize(size)
    }
    
    // TODO: This isn't really used anymore, glyphs are done with instancing now.
    // This allow glyphs to be drawing without said instancing though.
    public override func applyTextures(_ sdp: inout SafeDrawPass) {
        sdp.renderCommandEncoder.setFragmentTexture(texture, index: 0)
    }
}

public extension MetalLinkGlyphNode {
    // Optional meta on nodes; I think I'm shifting to using these as the
    // carrier of truth since I have more control of where they come from.
    // I think SCNNode made it trickier to know what was what. I'm decreasing
    // flexibility and adding cohesion (coupling?). This is basically what I
    // encoded into SCNNode.name. This is more explicit.
    struct Meta {
        public var syntaxID: String? // TODO: This used to be `NodeSyntaxID`
        
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
