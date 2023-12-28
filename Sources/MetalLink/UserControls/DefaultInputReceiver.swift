//
//  DefaultInputReceiver.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import Combine

#if os(iOS)
import UIKit
#endif

public extension DefaultInputReceiver {
    static var shared = DefaultInputReceiver()
}

public class DefaultInputReceiver: ObservableObject, MousePositionReceiver, KeyDownReceiver {
    private let mouseSubject = PassthroughSubject<OSEvent, Never>()
    private let scrollSubject = PassthroughSubject<OSEvent, Never>()
    private let mouseDownSubject = PassthroughSubject<OSEvent, Never>()
    private let mouseUpSubject = PassthroughSubject<OSEvent, Never>()
    private let keyEventSubject = PassthroughSubject<OSEvent, Never>()
    
    public lazy var sharedMouse = mouseSubject.share().eraseToAnyPublisher()
    public lazy var sharedScroll = scrollSubject.share().eraseToAnyPublisher()
    public lazy var sharedMouseDown = mouseDownSubject.share().eraseToAnyPublisher()
    public lazy var sharedMouseUp = mouseUpSubject.share().eraseToAnyPublisher()
    public lazy var sharedKeyEvent = keyEventSubject.share().eraseToAnyPublisher()
    
    #if os(iOS)
    private let touchMoveSubject = PassthroughSubject<UITouch, Never>()
    public lazy var sharedTouchMovements = touchMoveSubject.share().eraseToAnyPublisher()
    public var touchMovementEvents: UITouch = UITouch() {
        didSet { touchMoveSubject.send(touchMovementEvents) }
    }
    #endif
    
    public var mousePosition: OSEvent = OSEvent() {
        didSet { mouseSubject.send(mousePosition) }
    }
    
    public var scrollEvent: OSEvent = OSEvent() {
        didSet { scrollSubject.send(scrollEvent) }
    }
    
    public var mouseDownEvent: OSEvent = OSEvent() {
        didSet { mouseDownSubject.send(mouseDownEvent) }
    }
    
    public var mouseUpEvent: OSEvent = OSEvent() {
        didSet { mouseUpSubject.send(mouseUpEvent) }
    }
    
    public var lastKeyEvent: OSEvent = OSEvent() {
        didSet { keyEventSubject.send(lastKeyEvent) }
    }
    
    public lazy var touchState: TouchState = TouchState()
    
    public lazy var gestureShim: GestureShim = GestureShim(
        shimPan: { print(#line, "Pan DefaultInput received: \($0)") },
        shimMagnify: { print(#line, "Mag DefaultInput received: \($0)") },
        shimTap: { print(#line, "Tap DefaultInput received: \($0)") }
    )
}
