//  
//
//  Created on 12/16/23.
//  

import Foundation
import Combine
import BitHandling

public extension DebugCamera {
    func bindToLink() {
        link.input.sharedKeyEvent.sink { event in
            self.interceptor.onNewKeyEvent(event)
        }.store(in: &cancellables)
        
        link.input.sharedMouseDown.sink { event in
            guard self.notBlockingFromScroll else { return }
            
            print("mouse down")
            self.startRotate = true
        }.store(in: &cancellables)
        
        link.input.sharedMouseUp.sink { event in
            guard self.notBlockingFromScroll else { return }
            
            print("mouse up")
            self.startRotate = false
        }.store(in: &cancellables)
        
        link.input.sharedMouse.sink { event in
            guard self.startRotate else { return }
            
            self.interceptor.positions.rotationDelta.y = event.deltaX.float / 5
            self.interceptor.positions.rotationDelta.x = event.deltaY.float / 5
            self.scrollBounds = nil
        }.store(in: &cancellables)
        
        connectToPlatformInput()
    }
    
    func bindToInterceptor() {
        interceptor.positionSource = self
        
        interceptor.positions.$travelOffset.sink { total in
            var total = total
            if self.scrollLock.contains(.horizontal) { total.x = 0 }
            if self.scrollLock.contains(.vertical)   { total.y = 0 }
            if self.scrollLock.contains(.transverse) { total.z = 0 }
            
            self.moveCameraLocation(total / 100)
        }.store(in: &cancellables)
        
        interceptor.positions.$rotationDelta.sink { total in
            guard self.notBlockingFromScroll else { return }
            
            self.rotation += (total / 100)
        }.store(in: &cancellables)
    }
}

// MARK: -- macOS
#if os(macOS)
extension DebugCamera {
    func connectToPlatformInput() {
        link.input.sharedScroll.sink { event in
            let (horizontalLock, verticalLock, transverseLock) = (
                self.scrollLock.contains(.horizontal),
                self.scrollLock.contains(.vertical),
                self.scrollLock.contains(.transverse)
            )
            
            let sensitivity: Float = GlobalLiveConfig.Default.scrollSpeed
            let sensitivityModified = GlobalLiveConfig.Default.scrollSpeedModified
            
            let speedModified = self.interceptor.state.currentModifiers.contains(.shift)
            let inOutModifier = self.interceptor.state.currentModifiers.contains(.option)
            let multiplier = speedModified ? sensitivityModified : sensitivity
            
            var dX: Float {
                let final = -event.scrollingDeltaX.float * multiplier
                return final
            }
            var dY: Float {
                let final = inOutModifier ? 0 : event.scrollingDeltaY.float * multiplier
                return final
            }
            var dZ: Float {
                let final = inOutModifier ? -event.scrollingDeltaY.float * multiplier : 0
                return final
            }
            
            let delta = LFloat3(
                horizontalLock ? 0.0 : dX,
                verticalLock ? 0.0 : dY,
                transverseLock ? 0.0 : dZ
            )

//            print("--")
//            print("camera: ", self.position)
//            print("delta: ", delta)
//            print("sbounds: ", self.scrollBounds.map { "\($0.min), \($0.max)" } ?? "none" )
            
            self.interceptor.positions.travelOffset = delta
        }.store(in: &cancellables)
        
    }
}
#endif

// MARK: -- iOS

#if os(iOS)
extension DebugCamera {
    func connectToPlatformInput() {
        
        let panSubject = PassthroughSubject<PanEvent, Never>()
        let magnificationSubject = PassthroughSubject<MagnificationEvent, Never>()
        panSubject
            .scan(PanEvent.newEmptyPair) { ($0.1, $1) }
            .filter { $0.0.currentLocation != $0.1.currentLocation }
            .sink { [interceptor] pair in
                guard pair.1.state == .changed else { return }
                
                let delta = pair.1.currentLocation - pair.0.currentLocation
                interceptor.positions.travelOffset = LFloat3(
                    -delta.x * 250,
                     delta.y * 250,
                     0
                )
            }.store(in: &cancellables)
        
        magnificationSubject
            .scan(MagnificationEvent.newEmptyPair) { ($0.1, $1) }
            .filter { $0.0.magnification != $0.1.magnification }
            .sink { [interceptor] pair in
                let next: MagnificationEvent = pair.1
                guard next.state == .changed else { return }
                let delta = (1 - next.magnification) * 100_000
                interceptor.positions.travelOffset = LFloat3(0, 0, delta)
            }.store(in: &cancellables)
        
        // Yes, the closure will retain the subject <3
        link.input.gestureShim.onPan = panSubject.send
        link.input.gestureShim.onMagnify = magnificationSubject.send
        
    }
}
#endif
