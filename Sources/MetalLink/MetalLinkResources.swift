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
    
//    public static func moduleBundle() -> Bundle {
//        Bundle.module
//    }
    
    public static func shaderBundle() -> Bundle {
        let myBundle = Bundle(for: MetalLinkResources.self)
//        let myBundle = Bundle.main
        guard let resourceURL = myBundle.resourceURL else {
            print("Missing resource bundle url")
            return .main
        }
        let shaderBundleURL = resourceURL.appending(path: "MetalLink_MetalLinkResources.bundle", directoryHint: .checkFileSystem)
        guard let shaderBundle = Bundle(url: shaderBundleURL) else {
            print("Missing shader bundle")
            return .main
        }
        
        return shaderBundle
    }
    
    public static func getShaderLibrary(from device: MTLDevice) -> MTLLibrary? {
        let shaderBundle = shaderBundle()
        guard let libraryURL = shaderBundle.url(forResource: "debug", withExtension: "metallib") else {
            print("Missing library URL")
            return nil
        }
        let library = try? device.makeLibrary(URL: libraryURL)
        return library
    }
    
//    public static func getDefaultLibrary_OLD(from device: MTLDevice) -> MTLLibrary? {
//        do {
//            return try device.makeDefaultLibrary(bundle: moduleBundle())
//        } catch {
//            print("[\(#fileID):\(#function)] - Library Error - \(error)")
//            return nil
//        }
//    }
}


