//  
//
//  Created on 12/17/23.
//  

import Foundation
import MetalKit
import BitHandling

// MARK: - Kernel functions + Pipeline states

enum LinkFunctionTargets: String {
    case rawRenderName = "utf8ToUtf32Kernel"
    case atlasRenderName = "utf8ToUtf32KernelAtlasMapped"
    case fastLayoutKernelName = "utf32GlyphMap_FastLayout"
    case fastLayoutPaginateKernelName = "utf32GlyphMap_FastLayout_Paginate"
    case compressionKernalName = "processNewUtf32AtlasMapping"
    case constantsBlitKernelName = "blitGlyphsIntoConstants"
    case searchGlyphsKernelName = "searchGlyphs"
    case clearSearchGlyphsKernelName = "clearSearchGlyphs"
    
    private func functionInstance(_ link: MetalLink) -> MTLFunction? {
        link.library.makeFunction(name: rawValue)
    }
    
    func makePipelineState(_ link: MetalLink) throws -> MTLComputePipelineState {
        guard let function = functionInstance(link)
        else { throw ComputeError.missingFunction(rawValue) }
        return try link.device.makeComputePipelineState(function: function)
    }
}

internal class ConvertComputeFunctions: MetalLinkReader {
    var cache = [LinkFunctionTargets: MTLComputePipelineState]()
    let link: MetalLink
    init(link: MetalLink) { self.link = link }
    
    let lock = LockWrapper()
    func cached(_ key: LinkFunctionTargets) throws -> MTLComputePipelineState {
        lock.writeLock()
        if let function = cache[key] {
            lock.unlock()
            return function
        }
        let newFunction = try key.makePipelineState(link)
        cache[key] = newFunction
        lock.unlock()
        return newFunction
    }
    
    func makeRawRenderPipelineState() throws -> MTLComputePipelineState {
        try cached(.rawRenderName)
    }

    func makeAtlasRenderPipelineState() throws -> MTLComputePipelineState {
        try cached(.atlasRenderName)
    }

    func makeFastLayoutRenderPipelineState() throws -> MTLComputePipelineState {
        try cached(.fastLayoutKernelName)
    }

    func makeFastLayoutPaginateRenderPipelineState() throws -> MTLComputePipelineState {
        try cached(.fastLayoutPaginateKernelName)
    }

    func makeCompressionRenderPipelineState() throws -> MTLComputePipelineState {
        try cached(.compressionKernalName)
    }

    func makeConstantsBlitPipelineState() throws -> MTLComputePipelineState {
        try cached(.constantsBlitKernelName)
    }

    func searchGlyphs() throws -> MTLComputePipelineState {
        try cached(.searchGlyphsKernelName)
    }

    func clearSearchGlyphs() throws -> MTLComputePipelineState {
        try cached(.clearSearchGlyphsKernelName)
    }
}
