//  
//
//  Created on 12/16/23.
//  

import Foundation

public enum ScrollLock: String, CaseIterable, Identifiable, Hashable {
    public var id: Self { self }
    case horizontal = "Hz"
    case vertical   = "Vt"
    case transverse = "Tx"
    
    public var systemImageName: String {
        switch self {
        case .horizontal:
            "arrow.left.arrow.right"
        case .vertical:
            "arrow.up.arrow.down"
        case .transverse:
            "road.lane.arrowtriangle.2.inward"
        }
    }
}
