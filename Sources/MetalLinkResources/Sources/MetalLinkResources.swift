//  
//
//  Created on 12/16/23.
//  

import Foundation
import Metal

public struct MetalLinkResources {
    private init() { }
    
    public static func moduleBundle() -> Bundle {
        Bundle.module
    }
    
    public static func getDefaultLibrary(from device: MTLDevice) -> MTLLibrary? {
        do {
            return try device.makeDefaultLibrary(bundle: moduleBundle())
        } catch {
            print("[\(#fileID):\(#function)] - Library Error - \(error)")
            return nil
        }
    }
}
