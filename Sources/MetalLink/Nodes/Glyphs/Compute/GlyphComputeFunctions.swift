//  
//
//  Created on 12/17/23.
//  

import Foundation
import MetalKit

// MARK: - Kernel functions + Pipeline states

internal class ConvertComputeFunctions: MetalLinkReader {
    let link: MetalLink
    init(link: MetalLink) { self.link = link }
    
    let rawRenderName = "utf8ToUtf32Kernel"
    lazy var rawRenderkernelFunction = library.makeFunction(name: rawRenderName)
    
    let atlasRenderName = "utf8ToUtf32KernelAtlasMapped"
    lazy var atlasRenderKernelFunction = library.makeFunction(name: atlasRenderName)
    
    let layoutKernelName = "utf32GlyphMapLayout"
    lazy var layoutKernelFunction = library.makeFunction(name: layoutKernelName)
    
    let fastLayoutKernelName = "utf32GlyphMap_FastLayout"
    lazy var fastLayoutKernelFunction = library.makeFunction(name: fastLayoutKernelName)
    
    let compressionKernalName = "processNewUtf32AtlasMapping"
    lazy var compressionKernelFunction = library.makeFunction(name: compressionKernalName)
    
    let constantsBlitKernelName = "blitGlyphsIntoConstants"
    lazy var constantsBlitKernelFunction = library.makeFunction(name: constantsBlitKernelName)
    
    func makeRawRenderPipelineState() throws -> MTLComputePipelineState {
        guard let rawRenderkernelFunction
        else { throw ComputeError.missingFunction(rawRenderName) }
        return try device.makeComputePipelineState(function: rawRenderkernelFunction)
    }
    
    func makeAtlasRenderPipelineState() throws -> MTLComputePipelineState {
        guard let atlasRenderKernelFunction
        else { throw ComputeError.missingFunction(atlasRenderName) }
        return try device.makeComputePipelineState(function: atlasRenderKernelFunction)
    }
    
    func makeLayoutRenderPipelineState() throws -> MTLComputePipelineState {
        guard let layoutKernelFunction
        else { throw ComputeError.missingFunction(layoutKernelName) }
        return try device.makeComputePipelineState(function: layoutKernelFunction)
    }
    
    func makeFastLayoutRenderPipelineState() throws -> MTLComputePipelineState {
        guard let fastLayoutKernelFunction
        else { throw ComputeError.missingFunction(fastLayoutKernelName) }
        return try device.makeComputePipelineState(function: fastLayoutKernelFunction)
    }
    
    func makeCompressionRenderPipelineState() throws -> MTLComputePipelineState {
        guard let compressionKernelFunction
        else { throw ComputeError.missingFunction(compressionKernalName) }
        return try device.makeComputePipelineState(function: compressionKernelFunction)
    }
    
    func makeConstantsBlitPipelineState() throws -> MTLComputePipelineState {
        guard let constantsBlitKernelFunction
        else { throw ComputeError.missingFunction(constantsBlitKernelName) }
        return try device.makeComputePipelineState(function: constantsBlitKernelFunction)
    }
}
