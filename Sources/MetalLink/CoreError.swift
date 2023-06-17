//
//  CoreError.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/6/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import Foundation

public enum CoreError: String, Error {
    case noMetalDevice
    case noCommandQueue
    case noDefaultLibrary
    case noBufferAvailable
    case noStencilDescriptor
}

public enum CoreShaderError: Error {
    case missingLibraryFunction(name: String)
}
