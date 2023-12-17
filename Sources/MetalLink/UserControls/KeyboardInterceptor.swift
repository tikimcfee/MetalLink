//
//  KeyboardCameraController.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 11/4/21.
//

import BitHandling
import Combine

public typealias FileOperationReceiver = (FileOperation) -> Void
public enum FileOperation {
    case openDirectory
}

public typealias FocusChangeReceiver = (SelfRelativeDirection) -> Void

public extension KeyboardInterceptor {
    class State: ObservableObject {
        @Published var directions: Set<SelfRelativeDirection> = []
#if os(iOS)
        @Published var currentModifiers: OSEvent.ModifierFlags = OSEvent.ModifierFlags.none
#else
        @Published var currentModifiers: OSEvent.ModifierFlags = OSEvent.ModifierFlags()
#endif
        
        // TODO: Track all focus directions and provide a trail?
        @Published var focusPath: [SelfRelativeDirection] = []
    }
    
    class Positions: ObservableObject {
        @Published var totalOffset: LFloat3 = .zero
        @Published var travelOffset: LFloat3 = .zero
        @Published var rotationOffset: LFloat3 = .zero
        @Published var rotationDelta: LFloat3 = .zero
        
        func reset() {
            totalOffset = .zero
            travelOffset = .zero
            rotationOffset = .zero
            rotationDelta = .zero
        }
    }
}

public protocol KeyboardPositionSource {
    var worldUp: LFloat3 { get }
    var worldRight: LFloat3 { get }
    var worldFront: LFloat3 { get }
    var rotation: LFloat3 { get }
}

public class KeyboardInterceptor {
    
    private(set) var state = State()
    private(set) var positions = Positions()
    
    public var onNewFileOperation: FileOperationReceiver?
    public var onNewFocusChange: FocusChangeReceiver?
    public var positionSource: KeyboardPositionSource?
    
    public init(onNewFileOperation: FileOperationReceiver? = nil) {
        self.onNewFileOperation = onNewFileOperation
    }
    
    public func resetPositions() {
        positions.reset()
    }
    
    public func onNewKeyEvent(_ event: OSEvent) {
        enqueuedKeyConsume(event)
    }
    
    public func runCurrentInterceptedState() {
        runLoopImplementation()
    }
    
    private func runLoopImplementation() {
        guard !state.directions.isEmpty else {
            return
        }
        
        let finalDelta = state.currentModifiers.contains(.shift)
            ? GlobalLiveConfig.Default.modifiedMovementSpeed
            : GlobalLiveConfig.Default.movementSpeed
        
        state.directions.forEach { direction in
            doDirectionDelta(direction, finalDelta)
        }
    }
    
    private func startMovement(_ direction: SelfRelativeDirection) {
        guard !state.directions.contains(direction) else { return }
        print("start", direction)
        state.directions.insert(direction)
    }
    
    private func stopMovement(_ direction: SelfRelativeDirection) {
        guard state.directions.contains(direction) else { return }
        print("stop", direction)
        state.directions.remove(direction)
    }
}

private extension KeyboardInterceptor {
    func doDirectionDelta(
        _ direction: SelfRelativeDirection,
        _ finalDelta: VectorFloat
    ) {
        guard let source = self.positionSource else { return }
        
        var positionOffset: LFloat3 = .zero
        var rotationOffset: LFloat3 = .zero
        
        switch direction {
        case .forward:
            positionOffset = source.worldFront * Float(finalDelta)
        case .backward:
            positionOffset = source.worldFront * -Float(finalDelta)
            
        case .right:
            positionOffset = source.worldRight * Float(finalDelta)
        case .left:
            positionOffset = source.worldRight * -Float(finalDelta)
            
        case .up:
            positionOffset = source.worldUp * Float(finalDelta)
        case .down:
            positionOffset = source.worldUp * -Float(finalDelta)
            
        case .yawLeft:
            rotationOffset = LFloat3(0, -5, 0)
        case .yawRight:
            rotationOffset = LFloat3(0, 5, 0)
        }
        
        positions.totalOffset += positionOffset
        positions.travelOffset = positionOffset
        positions.rotationOffset += rotationOffset
        positions.rotationDelta = rotationOffset
    }
}

#if os(iOS)
import UIKit
public extension OSEvent {
    class ModifierFlags: Equatable {
        public static let none = ModifierFlags(-1)
        public static let shift = ModifierFlags(0)
        public static let command = ModifierFlags(1)
        public static let options = ModifierFlags(2)
        let id: Int
        private init(_ id: Int) { self.id = id }
        
        public static func == (lhs: UIEvent.ModifierFlags, rhs: UIEvent.ModifierFlags) -> Bool {
            return lhs.id == rhs.id
        }
        
        public func contains(_ flags: ModifierFlags) -> Bool {
            id == flags.id
        }
    }
    
    static let LeftDragKeydown = OSEvent()
    static let LeftDragKeyup = OSEvent()
    
    static let RightDragKeydown = OSEvent()
    static let RightDragKeyup = OSEvent()
    
    static let DownDragKeydown = OSEvent()
    static let DownDragKeyup = OSEvent()
    
    static let UpDragKeydown = OSEvent()
    static let UpDragKeyup = OSEvent()
    
    static let InDragKeydown = OSEvent()
    static let InDragKeyup = OSEvent()
    
    static let OutDragKeydown = OSEvent()
    static let OutDragKeyup = OSEvent()
}

private extension KeyboardInterceptor {
    func enqueuedKeyConsume(_ event: OSEvent) {
        switch event {
        case .RightDragKeydown: startMovement(.right)
        case .RightDragKeyup: stopMovement(.right)
            
        case .LeftDragKeydown: startMovement(.left)
        case .LeftDragKeyup: stopMovement(.left)
            
        case .UpDragKeydown: startMovement(.down)
        case .UpDragKeyup: stopMovement(.down)
            
        case .DownDragKeydown: startMovement(.up)
        case .DownDragKeyup: stopMovement(.up)
            
        case .InDragKeydown: startMovement(.forward)
        case .InDragKeyup: stopMovement(.forward)
            
        case .OutDragKeydown: startMovement(.backward)
        case .OutDragKeyup: stopMovement(.backward)
        
        default: break
        }
    }
}
#elseif os(macOS)
private extension KeyboardInterceptor {
    
    // Accessing fields from incorrect NSEvent types is incredibly unsafe.
    //  You must check type before access, and ensure any fields are expected to be returned.
    //  E.g., `event.characters` results in an immediate fatal exception thrown if the type is NOT .keyDown or .keyUp
    // We break up the fields on type to make slightly safer assumptions in the implementation
    func enqueuedKeyConsume(_ event: OSEvent) {
        switch event.type {
        case .keyDown:
            onKeyDown(event.characters ?? "", event)
            
        case .keyUp:
            onKeyUp(event.characters ?? "", event)
            
        case .flagsChanged:
            onFlagsChanged(event.modifierFlags, event)
            
        default:
            break
        }
    }
    
    private func onKeyDown(_ characters: String, _ event: OSEvent) {
        if let moveDirection = directionForKey(characters) {
            startMovement(moveDirection)
        } else if let focusDirection = focusDirectionForKey(characters, event) {
            changeFocus(focusDirection)
        } else {
            // MARK: - Shortcuts
            // Probably need a shortcut shim thing here.. oof..
            switch characters {
            case "o" where event.modifierFlags.contains(.command):
                onNewFileOperation?(.openDirectory)
            default:
                break
            }
        }
    }
    
    private func onKeyUp(_ characters: String, _ event: OSEvent) {
        guard let direction = directionForKey(characters) else {
            return
        }
        stopMovement(direction)
    }
    
    private func onFlagsChanged(_ flags: OSEvent.ModifierFlags, _ event: OSEvent) {
        state.currentModifiers = flags
        
        /// This is to try and fix the stuck key thing.  So there's some kind of 'unknown' flag
        /// with value 256 that occurs after repeated characters and combination keys. We interpret this as:
        /// "the keyboard has stopped doing weird stuff magic stuff, clear state and assume things will work"
        if flags.__unsafe__isUnknown {
            state.directions.removeAll(keepingCapacity: true)
        }
    }
    
    private func changeFocus(_ focusDirection: SelfRelativeDirection) {
        state.focusPath.append(focusDirection)
        onNewFocusChange?(focusDirection)
    }
}

extension NSEvent.ModifierFlags: CustomStringConvertible {
    public var description: String {
        var modifiers = ""
        
        func add(_ name: String) {
            modifiers = modifiers.isEmpty ? name : "\(modifiers) + \(name)"
        }

        if self.contains(NSEvent.ModifierFlags.capsLock) {
            add("capsLock")
        }
        if self.contains(NSEvent.ModifierFlags.shift) {
            add("shift")
        }
        if self.contains(NSEvent.ModifierFlags.control) {
            add("control")
        }
        if self.contains(NSEvent.ModifierFlags.option) {
            add("option")
        }
        if self.contains(NSEvent.ModifierFlags.command) {
            add("command")
        }
        if self.contains(NSEvent.ModifierFlags.numericPad) {
            add("numericPad")
        }
        if self.contains(NSEvent.ModifierFlags.help) {
            add("help")
        }
        if self.contains(NSEvent.ModifierFlags.function) {
            add("function")
        }
        if self.contains(NSEvent.ModifierFlags.deviceIndependentFlagsMask) {
            add("mask")
        }

        if modifiers.isEmpty {
            add("unknown-modifier-\(rawValue)")
        }

        return modifiers
    }
    
    var __unsafe__isUnknown: Bool {
        rawValue == 256
    }
}

extension NSEvent.EventType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .leftMouseDown:
            return "leftMouseDown"
        case .leftMouseUp:
            return "leftMouseUp"
        case .rightMouseDown:
            return "rightMouseDown"
        case .rightMouseUp:
            return "rightMouseUp"
        case .mouseMoved:
            return "mouseMoved"
        case .leftMouseDragged:
            return "leftMouseDragged"
        case .rightMouseDragged:
            return "rightMouseDragged"
        case .mouseEntered:
            return "mouseEntered"
        case .mouseExited:
            return "mouseExited"
        case .keyDown:
            return "keyDown"
        case .keyUp:
            return "keyUp"
        case .flagsChanged:
            return "flagsChanged"
        case .appKitDefined:
            return "appKitDefined"
        case .systemDefined:
            return "systemDefined"
        case .applicationDefined:
            return "applicationDefined"
        case .periodic:
            return "periodic"
        case .cursorUpdate:
            return "cursorUpdate"
        case .scrollWheel:
            return "scrollWheel"
        case .tabletPoint:
            return "tabletPoint"
        case .tabletProximity:
            return "tabletProximity"
        case .otherMouseDown:
            return "otherMouseDown"
        case .otherMouseUp:
            return "otherMouseUp"
        case .otherMouseDragged:
            return "otherMouseDragged"
        case .gesture:
            return "gesture"
        case .magnify:
            return "magnify"
        case .swipe:
            return "swipe"
        case .rotate:
            return "rotate"
        case .beginGesture:
            return "beginGesture"
        case .endGesture:
            return "endGesture"
        case .smartMagnify:
            return "smartMagnify"
        case .quickLook:
            return "quickLook"
        case .pressure:
            return "pressure"
        case .directTouch:
            return "directTouch"
        case .changeMode:
            return "changeMode"
        @unknown default:
            return "unknown-key-\(rawValue)"
        }
    }
}


#endif

func directionForKey(_ key: String) -> SelfRelativeDirection? {
    switch key {
    case "a", "A": return .left
    case "d", "D": return .right
    case "w", "W": return .forward
    case "s", "S": return .backward
    case "z", "Z": return .down
    case "x", "X": return .up
    case "q", "Q": return .yawLeft
    case "e", "E": return .yawRight
    default: return nil
    }
}

func focusDirectionForKey(_ key: String, _ event: OSEvent) -> SelfRelativeDirection? {
    switch key {
    case "h", "H": return .left
    case "l", "L": return .right
    case "j", "J": return .down
    case "k", "K": return .up
    case "n", "N": return .forward
    case "m", "M": return .backward
    #if os(macOS)
    case _ where event.specialKey == .leftArrow: return .left
    case _ where event.specialKey == .rightArrow: return .right
    case _ where event.specialKey == .upArrow && event.modifierFlags.contains(.shift): return .forward
    case _ where event.specialKey == .downArrow && event.modifierFlags.contains(.shift): return .backward
    case _ where event.specialKey == .upArrow: return .up
    case _ where event.specialKey == .downArrow: return .down
    #endif
    default: return nil
    }
}


class MLLooper {
    let loop: () -> Void
    let queue: DispatchQueue
    
    var interval: DispatchTimeInterval
    var nextDispatch: DispatchTime { .now() + interval }
    
    init(interval: DispatchTimeInterval = .seconds(1),
         loop: @escaping () -> Void,
         queue: DispatchQueue = .main) {
        self.interval = interval
        self.loop = loop
        self.queue = queue
    }
    
    func runUntil(
        onStop: (() -> Void)? = nil,
        _ stopCondition: @escaping () -> Bool
    ) {
        guard !stopCondition() else {
            onStop?()
            return
        }
        loop()
        queue.asyncAfter(deadline: nextDispatch) {
            self.runUntil(onStop: onStop, stopCondition)
        }
    }
}
