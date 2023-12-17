import Foundation
import SwiftUI

public typealias PanReceiver = (PanEvent) -> Void
public typealias MagnificationReceiver = (MagnificationEvent) -> Void
public typealias TapReceiver = (GestureEvent) -> Void

#if os(OSX)

public class GestureShim {
    lazy var panRecognizer =
        ModifiersPanGestureRecognizer(target: self, action: #selector(pan))
    var onPan: PanReceiver

    lazy var magnificationRecognizer =
        ModifiersMagnificationGestureRecognizer(target: self, action: #selector(magnify))
    var onMagnify: MagnificationReceiver
    
    lazy var tapGestureRecognizer =
        TapGestureRecognizer(target: self, action: #selector(tap))
    var onTap: TapReceiver

    init(_ onPan: @escaping PanReceiver,
         _ onMagnify: @escaping MagnificationReceiver,
         _ onTap: @escaping TapReceiver) {
        self.onPan = onPan
        self.onMagnify = onMagnify
        self.onTap = onTap
        
        tapGestureRecognizer.isEnabled = false
    }
    
    @objc func tap(_ receiver: TapGestureRecognizer) {
        onTap(receiver.makeTapEvent)
    }

    @objc func pan(_ receiver: ModifiersPanGestureRecognizer) {
        onPan(receiver.makePanEvent)
    }

    @objc func magnify(_ receiver: ModifiersMagnificationGestureRecognizer) {
        onMagnify(receiver.makeMagnificationEvent)
    }
}

#elseif os(iOS)

public class GestureShim {
    public private(set) lazy var panRecognizer = PanGestureRecognizer(
        target: self,
        action: #selector(pan)
    )
    
    public private(set) lazy var magnificationRecognizer = MagnificationGestureRecognizer(
        target: self,
        action: #selector(magnify)
    )
    
    public private(set) lazy var tapGestureRecognizer = TapGestureRecognizer(
        target: self,
        action: #selector(tap)
    )
    
    public var onPan: PanReceiver
    public var onMagnify: MagnificationReceiver
    public var onTap: TapReceiver
    
    init(_ onPan: @escaping PanReceiver,
         _ onMagnify: @escaping MagnificationReceiver,
         _ onTap: @escaping TapReceiver) {
        self.onPan = onPan
        self.onMagnify = onMagnify
        self.onTap = onTap
    }
    
    @objc func tap(_ receiver: TapGestureRecognizer) {
        onTap(receiver.makeGestureEvent)
    }
    
    @objc func pan(_ receiver: PanGestureRecognizer) {
        onPan(receiver.makePanEvent)
    }
    
    @objc func magnify(_ receiver: MagnificationGestureRecognizer) {
        onMagnify(receiver.makeMagnificationEvent)
        receiver.scale = 1
    }
}

#endif

public extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(point.x - x, 2) + pow(point.y - y, 2))
    }

    func scaled(_ factor: CGFloat) -> CGPoint {
        return CGPoint(x: x * factor, y: y * factor)
    }
    
    var asSimd: LFloat2 { LFloat2(x.float, y.float) }
}

public class TouchState {
    public var magnify: MagnifyStart
    public var mouse: Mouse
    
    init(
        magnify: MagnifyStart = MagnifyStart(),
        mouse: Mouse = Mouse()
    ) {
        self.magnify = magnify
        self.mouse = mouse
    }
}

public class Mouse {
    public var currentPosition = CGPoint()
}

public class MagnifyStart {
    public var lastScaleZ = CGFloat(1.0)
}

