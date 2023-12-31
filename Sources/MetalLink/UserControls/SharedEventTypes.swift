import Foundation

public enum EventState {
    case began, changed, ended
}

public enum EventType {
    case deviceTap
}

public struct MagnificationEvent {
    public var state: EventState?

    public let rawMagnification: VectorFloat
    public var magnification: VectorFloat {
        #if os(iOS)
        return rawMagnification
        #elseif os(OSX)
        return rawMagnification + 1
        #endif
    }
    
    public static var newEmpty: MagnificationEvent { MagnificationEvent(rawMagnification: .zero) }
    public static var newEmptyPair: (MagnificationEvent, MagnificationEvent) { (.newEmpty, .newEmpty) }
}

public struct PanEvent {
    public static var newEmpty: PanEvent { PanEvent(currentLocation: .zero) }
    public static var newEmptyPair: (PanEvent, PanEvent) { (.newEmpty, .newEmpty) }
    
    public var state: EventState?
    public let currentLocation: LFloat2

    public var commandStart: LFloat2?
    public var pressingCommand: Bool { commandStart != nil }
    public var optionStart: LFloat2?
    public var pressingOption: Bool { optionStart != nil }
    public var controlStart: LFloat2?
    public var pressingControl: Bool { controlStart != nil }
    public var shiftStart: LFloat2?
    public var pressingShift: Bool { shiftStart != nil }
    
    public init(
        state: EventState? = nil,
        currentLocation: LFloat2,
        commandStart: LFloat2? = nil,
        optionStart: LFloat2? = nil,
        shiftStart: LFloat2? = nil,
        controlStart: LFloat2? = nil
    ) {
        self.state = state
        self.currentLocation = currentLocation
        self.commandStart = commandStart
        self.optionStart = optionStart
        self.shiftStart = shiftStart
        self.controlStart = controlStart
    }
}

public struct GestureEvent {
    public let state: EventState?
    public let type: EventType?
    
    public let currentLocation: LFloat2
    
    public var commandStart: LFloat2?
    public var pressingCommand: Bool { commandStart != nil }
    
    public var optionStart: LFloat2?
    public var pressingOption: Bool { optionStart != nil }
    
    public var controlStart: LFloat2?
    public var pressingControl: Bool { controlStart != nil }
}
