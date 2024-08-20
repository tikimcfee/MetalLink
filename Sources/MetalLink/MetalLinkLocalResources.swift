//
//  File.swift
//  
//
//  Created by Ivan Lugo on 6/8/23.
//

import Foundation
import Metal
import MetalLinkResources

public class MetalLinkLocalResources {
    private init() { }
    
    private static func shaderBundle() -> Bundle? {
        let myBundle = Bundle(for: MetalLinkLocalResources.self)
        guard let resourceURL = myBundle.resourceURL else {
            print("Missing resource bundle url")
            return nil
        }
        
        let shaderBundleURL = resourceURL.appending(path: "MetalLink_MetalLinkResources.bundle", directoryHint: .checkFileSystem)
        guard let shaderBundle = Bundle(url: shaderBundleURL) else {
            print("Missing shader bundle")
            return nil
        }
        
        return shaderBundle
    }
    
    public static func getDefaultLibrary(from device: MTLDevice) -> MTLLibrary? {
        return MetalLinkResources.getDefaultLibrary(from: device)
    }
    
    public static func getDebugShaderLibrary(from device: MTLDevice) -> MTLLibrary? {
        let shaderBundle = shaderBundle()
        let libraryURL = shaderBundle?.url(forResource: "debug", withExtension: "metallib")
        guard let libraryURL else {
            print("Missing library URL")
            return nil
        }
        guard let library = try? device.makeLibrary(URL: libraryURL) else {
            print("Cannot find debug metallib, reverting to 'makeDefaultLibrary")
            return device.makeDefaultLibrary()
        }
        return library
    }
}


