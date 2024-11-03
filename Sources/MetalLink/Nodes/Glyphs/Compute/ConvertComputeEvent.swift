//  
//
//  Created on 12/17/23.
//  

import Foundation
import BitHandling
import MetalKit

public extension ConvertCompute {
    enum Event {
        case bufferMapped(String)
        case layoutEncoded(String)
        case copyEncoded(String)
        case collectionReady(String)
        
        var name: String {
            switch self {
            case let .bufferMapped(name),
                let .layoutEncoded(name),
                let .copyEncoded(name),
                let .collectionReady(name):
                return name
            }
        }
    }
}
