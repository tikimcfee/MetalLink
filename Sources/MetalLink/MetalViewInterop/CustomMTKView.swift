//
//  CustomMTKView.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/29/22.
//

import Foundation
import MetalKit
import SwiftUI

#if !os(visionOS)

public class CustomMTKView: MTKView {
    weak var positionReceiver: MousePositionReceiver?
    weak var keyDownReceiver: KeyDownReceiver?
    
    #if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
//        print("START-------------")
//        touches.forEach { touch in
//            print("at: \(touch.location(in: self))")
//        }
//        print("xxx-------------xxx")
    }
    
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
//        print("-----MOVE--------")
//        touches.prefix(1).forEach { touch in
//            
//        }
//        print("xxx-------------xxx")
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
//        print("-------------END")
//        touches.forEach { touch in
//            print("at: \(touch.location(in: self))")
//        }
//        print("xxx-------------xxx")
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
//        print("-------------~~~ Cancelled")
//        touches.forEach { touch in
//            
//        }
//        print("xxx-------------xxx")
    }
    
    //    - (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
    
    #endif
    
    #if os(macOS)
    var trackingArea : NSTrackingArea?
    
    public override func scrollWheel(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        super.scrollWheel(with: event)
        guard let receiver = positionReceiver,
              event.type == .scrollWheel else { return }
        receiver.scrollEvent = event.copy() as! NSEvent
    }
    
    public override func updateTrackingAreas() {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseMoved,
                .enabledDuringMouseDrag,
                .inVisibleRect,
                .activeAlways
            ],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea!)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        super.mouseMoved(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mousePosition = event.copy() as! NSEvent
    }
    
    public override func mouseDown(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        super.mouseDown(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mouseDownEvent = event.copy() as! NSEvent
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mouseUpEvent = event.copy() as! NSEvent
    }
    
    public override func keyDown(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        keyDownReceiver?.lastKeyEvent = event.copy() as! NSEvent
    }
    
    public override func keyUp(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        keyDownReceiver?.lastKeyEvent = event.copy() as! NSEvent
    }
    
    public override func otherMouseDragged(with event: NSEvent) {
        super.otherMouseDragged(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mousePosition = event.copy() as! NSEvent
    }
    
    public override func rightMouseDragged(with event: NSEvent) {
        super.rightMouseDragged(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mousePosition = event.copy() as! NSEvent
    }
    
    public override func mouseDragged(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        super.mouseDragged(with: event)
        guard let receiver = positionReceiver else { return }
        receiver.mousePosition = event.copy() as! NSEvent
    }
    
    public override func flagsChanged(with event: NSEvent) {
        // WARNING
        // DO NOT access NSEvents off of the main thread. Copy whatever information you need.
        // It is NOT SAFE to access these objects outside of this call scope.
        keyDownReceiver?.lastKeyEvent = event.copy() as! NSEvent
    }
    
    public override var acceptsFirstResponder: Bool {
        true
    }
    #endif
}

#endif


extension CustomMTKView {
    var defaultOrthographicProjection: simd_float4x4 {
        simd_float4x4(orthographicProjectionWithLeft: 0.0,
                      top: 0.0,
                      right: Float(drawableSize.width),
                      bottom: Float(drawableSize.height),
                      near: 0.0,
                      far: 1.0)
    }
}
