//
//  CustomMTKView.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/29/22.
//

import Foundation
import MetalKit
import SwiftUI

#if os(xrOS)
public class CustomMTKView: UIView {
    public var device: MTLDevice?
    public var drawableSize: MTLSize = .init(width: 0, height: 0, depth: 0)
    public var currentDrawable: CAMetalDrawable?
    public var colorPixelFormat: MTLPixelFormat = .abgr4Unorm
    public var currentRenderPassDescriptor: MTLRenderPassDescriptor?
    public var clearColor: MTLClearColor?
    public var preferredFramesPerSecond: Int = 60
    
    weak var positionReceiver: MousePositionReceiver?
    weak var keyDownReceiver: KeyDownReceiver?
    
    public init(frame: CGRect, device: MTLDevice) {
        self.device = device
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
