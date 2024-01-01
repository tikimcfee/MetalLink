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
    
    public var size: LFloat2 = .zero {
        didSet { quad.setSize(size) }
    }
    
    public override var hasIntrinsicSize: Bool {
        true
    }
    
    public override var contentBounds: Bounds {
        Bounds(
            LFloat3(-size.x / 2, size.y / 2, 0),
            LFloat3( size.x / 2, size.y / 2, 1)
        ) * scale
    }
    
    public init(_ link: MetalLink) {
        self.quad = MetalLinkQuadMesh(link)
        super.init(link, mesh: quad)
    }
    
    public override func doRender(in sdp: SafeDrawPass) {
        super.doRender(in: sdp)
    }
}

public extension BackgroundQuad {
    func applyTop(_ bounds: Bounds) {
        quad.topLeftPos = bounds.leadingTopFront
        quad.topRightPos = bounds.trailingTopFront
        quad.botLeftPos = bounds.leadingTopBack
        quad.botRightPos = bounds.trailingTopBack
    }
    
    func applyBottom(_ bounds: Bounds) {
        quad.topLeftPos = bounds.leadingBottomFront
        quad.topRightPos = bounds.trailingBottomFront
        quad.botLeftPos = bounds.leadingBottomBack
        quad.botRightPos = bounds.trailingBottomBack
    }
    
    func applyFront(_ bounds: Bounds) {
        quad.topLeftPos = bounds.leadingTopFront
        quad.topRightPos = bounds.trailingTopFront
        quad.botLeftPos = bounds.leadingBottomFront
        quad.botRightPos = bounds.trailingBottomFront
    }
    
    func applyBack(_ bounds: Bounds) {
        quad.topLeftPos = bounds.leadingTopBack
        quad.topRightPos = bounds.trailingTopBack
        quad.botLeftPos = bounds.leadingBottomBack
        quad.botRightPos = bounds.trailingBottomBack
    }
    
    func applyLeading(_ bounds: Bounds) {
        quad.topLeftPos = bounds.leadingTopFront
        quad.topRightPos = bounds.leadingTopBack
        quad.botLeftPos = bounds.leadingBottomFront
        quad.botRightPos = bounds.leadingBottomBack
    }
    
    func applyTrailing(_ bounds: Bounds) {
        quad.topLeftPos = bounds.trailingTopBack
        quad.topRightPos = bounds.trailingTopFront
        quad.botLeftPos = bounds.trailingBottomBack
        quad.botRightPos = bounds.trailingBottomFront
    }
}
