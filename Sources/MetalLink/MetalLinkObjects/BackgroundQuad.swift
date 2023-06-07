//
//  BackgroundQuad.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 9/14/22.
//

import Foundation

public class BackgroundQuad: MetalLinkObject, QuadSizable {
    public var quad: MetalLinkQuadMesh
    public var node: MetalLinkNode { self }
    
    public override var hasIntrinsicSize: Bool { true }
    
    public override var contentSize: LFloat3 {
        LFloat3(scale.x * 2, scale.y * 2, 1)
    }
    
    public override var contentOffset: LFloat3 {
        LFloat3(-scale.x, scale.y, 0)
    }
    
    public init(_ link: MetalLink) {
        self.quad = MetalLinkQuadMesh(link)
        super.init(link, mesh: quad)
    }
    
    public override func doRender(in sdp: inout SafeDrawPass) {
        super.doRender(in: &sdp)
    }
}
