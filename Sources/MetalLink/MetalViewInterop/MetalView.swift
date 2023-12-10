//  ATTRIBUTION TO:
//  [Created by Szymon Błaszczyński on 26/08/2021.]
// https://gist.githubusercontent.com/buahaha/19b27170e629276606ab2e057823de70/raw/a8c45e38988dc3654fb41ecec5411cef7849f3b5/MetalView.swift

import Foundation
import MetalKit
import SwiftUI

public struct MetalView: NSUIViewRepresentable {
    public var mtkView: CustomMTKView
    public var link: MetalLink
    public var renderer: MetalLinkRenderer
    
    public init(
        mtkView: CustomMTKView,
        link: MetalLink,
        renderer: MetalLinkRenderer
    ) {
        self.mtkView = mtkView
        self.link = link
        self.renderer = renderer
    }
    
    #if os(iOS)
    public func makeUIView(context: Context) -> some UIView {
        #if !os(xrOS)
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        #endif
        return mtkView
    }
    
    public func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    #elseif os(macOS)
    public func makeNSView(context: NSViewRepresentableContext<MetalView>) -> CustomMTKView {
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        return mtkView
    }
    
    public func updateNSView(_ nsView: CustomMTKView, context: NSViewRepresentableContext<MetalView>) {
        
    }
    #endif
    
    public func makeCoordinator() -> Coordinator {
        try! Coordinator(self, mtkView: mtkView)
    }
}

import Combine
public extension MetalView {
    class Coordinator {
        public var parent: MetalView
        public var renderer: MetalLinkRenderer
        
        public init(
            _ parent: MetalView,
            mtkView: CustomMTKView
        ) throws {
            self.parent = parent
            self.renderer = parent.renderer
            
            let link = parent.link
            
            mtkView.keyDownReceiver = link.input
            mtkView.positionReceiver = link.input
            
            #if os(iOS)
            print("-- Metal Gesture Recognizers --")
            print("This will disable some view events by default, like 'drag'")
            mtkView.addGestureRecognizer(link.input.gestureShim.tapGestureRecognizer)
            mtkView.addGestureRecognizer(link.input.gestureShim.magnificationRecognizer)
            mtkView.addGestureRecognizer(link.input.gestureShim.panRecognizer)
            print("-------------------------------")
            #endif
            
            #if !os(xrOS)
            mtkView.delegate = renderer
            mtkView.framebufferOnly = false
            mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            mtkView.drawableSize = mtkView.frame.size
            mtkView.enableSetNeedsDisplay = true
            #endif
        }
    }
}
