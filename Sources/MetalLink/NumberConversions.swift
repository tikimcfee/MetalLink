//
//  NumberConversions.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/31/22.
//

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Foundation
import CoreGraphics


public extension VectorFloat {
    var toDouble: Double {
        Double(self)
    }
}

public extension Double {
    var cg: CGFloat {
        return self
    }
    
    var float: Float {
        return Float(self)
    }
}

public extension CGFloat {
    var vector: VectorFloat {
        return VectorFloat(self)
    }
    
    var cg: CGFloat {
        return self
    }
}

public extension Int {
    var cg: CGFloat {
        return CGFloat(self)
    }
    
    var float: Float {
        return Float(self)
    }
}

public extension Float {
    var vector: VectorFloat {
        return VectorFloat(self)
    }
    
    var cg: CGFloat {
        return CGFloat(self)
    }
}

public extension CGFloat {
    var float: Float {
        return Float(self)
    }
}

public extension CGSize {
    var asSimd: LFloat2 {
        LFloat2(width.float, height.float)
    }
}
