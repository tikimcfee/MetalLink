//  
//
//  Created on 12/16/23.
//  

import Foundation

public enum ScrollLock: String, CaseIterable, Identifiable, Hashable {
    public var id: Self { self }
    case horizontal
    case vertical
    case transverse
}
