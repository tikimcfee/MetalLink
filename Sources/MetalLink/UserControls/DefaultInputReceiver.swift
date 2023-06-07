//
//  DefaultInputReceiver.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import Combine

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
        { print(#line, "DefaultInput received: \($0)") },
        { print(#line, "DefaultInput received: \($0)") },
        { print(#line, "DefaultInput received: \($0)") }
    )
}
