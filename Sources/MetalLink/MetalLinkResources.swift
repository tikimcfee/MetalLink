//
//  File.swift
//  
//
//  Created by Ivan Lugo on 6/8/23.
//

import Foundation
import Metal

public class MetalLinkResources {
    private init() { }
    
    public static func shaderBundle() -> Bundle? {
        let myBundle = Bundle(for: MetalLinkResources.self)
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
    
    public static func getShaderLibrary(from device: MTLDevice) -> MTLLibrary? {
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


