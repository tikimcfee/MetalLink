//
//  KeyboardCameraController.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 11/4/21.
//

import BitHandling
import Combine
import Foundation

#if os(macOS)
import AppKit
#endif

public typealias FileOperationReceiver = (FileOperation) -> Void
public enum FileOperation {
    case openDirectory
}

public typealias FocusChangeReceiver = (SelfRelativeDirection) -> Void

public extension KeyboardInterceptor {
    class State: ObservableObject {
        @Published public var directions: Set<SelfRelativeDirection> = []
#if os(iOS)
        @Published public var currentModifiers: OSEvent.ModifierFlags = OSEvent.ModifierFlags.none
#else
        @Published public var currentModifiers: OSEvent.ModifierFlags = OSEvent.ModifierFlags()
#endif
        
        // TODO: Track all focus directions and provide a trail?
        @Published public var focusPath: [SelfRelativeDirection] = []
    }
    
    class Positions: ObservableObject {
        @Published public var totalOffset: LFloat3 = .zero
        @Published public var travelOffset: LFloat3 = .zero
        @Published public var rotationOffset: LFloat3 = .zero
        @Published public var rotationDelta: LFloat3 = .zero
        
        public func reset() {
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
    
    public private(set) var state = State()
    public private(set) var positions = Positions()
    
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
            ? GlobalLiveConfig.Default.movementSpeedModified
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
            rotationOffset = LFloat3(0, -GlobalLiveConfig.Default.movementYawMagnitude, 0)
        case .yawRight:
            rotationOffset = LFloat3(0, GlobalLiveConfig.Default.movementYawMagnitude, 0)
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
        /// "the keyboard has stopped doing weird magic stuff, clear state and assume things will work"
        if flags.__unsafe__isUnknown {
            state.directions.removeAll(keepingCapacity: true)
        }
    }
    
    private func changeFocus(_ focusDirection: SelfRelativeDirection) {
        state.focusPath.append(focusDirection)
        onNewFocusChange?(focusDirection)
    }
}


#endif

func directionForKey(_ key: String) -> SelfRelativeDirection? {
    var map: Keymap { GlobalLiveConfig.Default.keymap }
    return map.movement[key]
}

func focusDirectionForKey(_ key: String, _ event: OSEvent) -> SelfRelativeDirection? {
    var map: Keymap { GlobalLiveConfig.Default.keymap }
    return map.focus[key]
}
