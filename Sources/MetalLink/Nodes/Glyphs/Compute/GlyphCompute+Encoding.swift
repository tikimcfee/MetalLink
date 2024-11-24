//  
//
//  Created on 12/17/23.
//  

import BitHandling
import Foundation
import MetalKit
import MetalLinkHeaders

// MARK: - Glyph Magic

public class EncodeResult {
    public enum Collection {
        case notBuilt
        case built(GlyphCollection)
    }
    
    public enum Blit {
        case notSet
        case set(MTLComputeCommandEncoder, InstanceState<GlyphCacheKey, GlyphNode>)
    }
    
    public let sourceURL: URL
    public let outputBuffer: MTLBuffer
    public let characterCountBuffer: MTLBuffer
    public let sourceEncoder: MTLComputeCommandEncoder
    public var blitEncoder = Blit.notSet
    public var collection = Collection.notBuilt
    
    public init(
        sourceURL: URL,
        outputBuffer: MTLBuffer,
        characterCountBuffer: MTLBuffer,
        sourceEncoder: MTLComputeCommandEncoder
    ) {
        self.sourceURL = sourceURL
        self.outputBuffer = outputBuffer
        self.characterCountBuffer = characterCountBuffer
        self.sourceEncoder = sourceEncoder
    }
    
    public var finalCount: UInt32 {
        characterCountBuffer.boundPointer(
            as: UInt32.self, count: 1
        ).pointee
    }
}

public extension ConvertCompute {
    
    // Give me .utf8 text data and an atlas buffer and I'll do even weirder things
    func setupAtlasLayoutCommandEncoder(
        for inputUTF8TextDataBuffer: MTLBuffer,
        in commandBuffer: MTLCommandBuffer,
        atlasBuffer: MTLBuffer
    ) throws -> (
        MTLBuffer,
        MTLBuffer,
        MTLComputeCommandEncoder
    ) {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        guard let computeCommandEncoder
        else { throw ComputeError.startupFailure }
        // Setup group for both encoding
        computeCommandEncoder.pushDebugGroup("[SG] Root Atlas Dispatch")
        
        // MARK: -- Fire up atlas
        let outputUTF32ConversionBuffer = try makeRawOutputBuffer(from: inputUTF8TextDataBuffer)
        let atlasPipelineState = try functions.makeAtlasRenderPipelineState()
        
        // Set the compute kernel's parameters
        computeCommandEncoder.setBuffer(inputUTF8TextDataBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(outputUTF32ConversionBuffer, offset: 0, index: 1)
        computeCommandEncoder.setBuffer(atlasBuffer, offset: 0, index: 2)
        
        // Pass the sizes of the buffer as constants
        var utf8BufferSize = inputUTF8TextDataBuffer.length
        computeCommandEncoder.setBytes(&utf8BufferSize, length: MemoryLayout<Int>.size, index: 3)
        
        var atlasBufferSize = atlasBuffer.length
        computeCommandEncoder.setBytes(&atlasBufferSize, length: MemoryLayout<Int>.size, index: 4)
        
        var utf32BufferSize = outputUTF32ConversionBuffer.length
        computeCommandEncoder.setBytes(&utf32BufferSize, length: MemoryLayout<Int>.size, index: 5)
        
        // And also pass a mutable count to tally up the total hashed up characters. This will be used to setup
        // a final output buffer.
        let characterCountBuffer = try makeCharacterCountBuffer(starting: 0)
        computeCommandEncoder.setBuffer(characterCountBuffer, offset: 0, index: 5)
        
        // Set the pipeline state
        computeCommandEncoder.setComputePipelineState(atlasPipelineState)
        
        // Calculate the number of threads and threadgroups
        // TODO: Explain why (boundsl, performance, et al), and make this better; this is probably off
        let threadGroupSize = MTLSize(width: atlasPipelineState.threadExecutionWidth, height: 1, depth: 1)
        let threadGroupsWidthCeil = (inputUTF8TextDataBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        let threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.pushDebugGroup("[SG] - Dispatch initial atlas map")
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        computeCommandEncoder.popDebugGroup()
        
        // MARK: -- Fire up layout. Oh boy.
        let layoutPipelineState = try functions.makeFastLayoutRenderPipelineState()
        computeCommandEncoder.setComputePipelineState(layoutPipelineState)
        
        // I guess we can reuse the set bytes and buffers and thread groups.. let's just hope, heh.
        computeCommandEncoder.pushDebugGroup("[SG] - Dispatching layout")
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        computeCommandEncoder.popDebugGroup()
        
        let paginatePipelineState = try functions.makeFastLayoutPaginateRenderPipelineState()
        computeCommandEncoder.setComputePipelineState(paginatePipelineState)
        
        // I guess we can reuse the set bytes and buffers and thread groups.. let's just hope, heh.
        computeCommandEncoder.pushDebugGroup("[SG] - Dispatching layout paginate")
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        computeCommandEncoder.popDebugGroup()
        
        // Finalize encoding
        computeCommandEncoder.popDebugGroup()
        computeCommandEncoder.endEncoding()
        
        return (
            outputUTF32ConversionBuffer,
            characterCountBuffer,
            computeCommandEncoder
        )
    }
    
    
    func searchConstants(
        in collection: GlyphCollection,
        with query: [CharacterHashType],
        clearOnly: Bool,
        using commandBuffer: MTLCommandBuffer
    ) throws -> (
        foundMatch: MTLBuffer,
//        debug: UnsafeMutablePointer<CharacterHashType>,
        encoder: MTLComputeCommandEncoder
    ) {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        guard let computeCommandEncoder
        else { throw ComputeError.startupFailure }
        
        computeCommandEncoder.pushDebugGroup("[SG] Root Search Dispatch")
        
        // Set the compute kernel's parameters
        let collectionBuffer = collection.instanceState.instanceBuffer;
        computeCommandEncoder.setBuffer(collectionBuffer, offset: 0, index: 0)
        
        var collectionSize = UInt(collection.instanceState.constants.endIndex)
        computeCommandEncoder.setBytes(&collectionSize, length: MemoryLayout<UInt>.stride, index: 1)
        
        var localQuery = query
        var localQueryLength = UInt(query.count)
        let localQueryByteLength: Int = CharacterHashType.memStride(of: query.count)
        computeCommandEncoder.setBytes(&localQuery, length: localQueryByteLength, index: 2)
        computeCommandEncoder.setBytes(&localQueryLength, length: MemoryLayout<UInt>.stride, index: 3)
        
        let foundMatchBuffer = try UInt.zero.asMetalBuffer(link)
        computeCommandEncoder.setBuffer(foundMatchBuffer, offset: 0, index: 4)
        
        // Debugging?
//        var debugBuffer = [CharacterHashType](repeating: 0, count: Int(collectionSize))
//        let debugLength = debugBuffer.count * MemoryLayout<CharacterHashType>.stride
//        let debugMetalBuffer = device.makeBuffer(bytes: &debugBuffer, length: debugLength)!
//        computeCommandEncoder.setBuffer(debugMetalBuffer, offset: 0, index: 5) // New debug buffer
        
        // Set the pipeline state
        let searchState = try functions.searchGlyphs()
        let clearSearchState = try functions.clearSearchGlyphs()
        
        // Calculate the number of threads and threadgroups
        let threadGroupSize = MTLSize(width: searchState.threadExecutionWidth, height: 1, depth: 1)
        let validStartPositions = collectionSize - UInt(query.count) + 1
        let threadGroupsWidthCeil = (Int(validStartPositions) + threadGroupSize.width - 1) / threadGroupSize.width
        let threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.setComputePipelineState(clearSearchState)
        computeCommandEncoder.pushDebugGroup("[SG] - Dispatch clear search")
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        computeCommandEncoder.popDebugGroup()
        
        if !clearOnly {
            computeCommandEncoder.setComputePipelineState(searchState)
            computeCommandEncoder.pushDebugGroup("[SG] - Dispatch search")
            computeCommandEncoder.dispatchThreadgroups(
                threadGroupsPerGrid,
                threadsPerThreadgroup: threadGroupSize
            )
            computeCommandEncoder.popDebugGroup()
        }
        
        // Finalize encoding
        computeCommandEncoder.popDebugGroup()
        computeCommandEncoder.endEncoding()
        
//        let debugPointer = debugMetalBuffer.boundPointer(as: CharacterHashType.self, count: debugLength)
        return (
            foundMatchBuffer,
//            debugPointer,
            computeCommandEncoder
        )
    }
    
    func setupCopyBlitCommandEncoder(
        for unprocessedBuffer: MTLBuffer,
        targeting targetConstants: InstanceState<GlyphCacheKey, MetalLinkGlyphNode>,
        expectedCharacterCount: UInt32,
        in commandBuffer: MTLCommandBuffer
    ) throws -> MTLComputeCommandEncoder {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        let constantsBlitPipelineState = try functions.makeConstantsBlitPipelineState()
        guard let computeCommandEncoder
        else { throw ComputeError.startupFailure }

        // MARK: -- Fire up Compressenator.
        
        // Source / target buffers
        computeCommandEncoder.setBuffer(unprocessedBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(targetConstants.constants.buffer, offset: 0, index: 1)
        
        // Source target total byte length,
        var unprocessedSize: Int = unprocessedBuffer.length / GlyphMapKernelOut.memStride
        computeCommandEncoder.setBytes(&unprocessedSize, length: Int.memSize, index: 2)
        
        var expectedCharacterCount: Int = Int(expectedCharacterCount)
        computeCommandEncoder.setBytes(&expectedCharacterCount, length: Int.memSize, index: 3)
        
        // Borrow the instance counter, lolz. // TODO: I didn't use this yet for the global id, oopselies
        let starting = UInt32(10)
        let instanceCountBuffer = try makeCharacterCountBuffer(starting: starting)
        computeCommandEncoder.setBuffer(instanceCountBuffer, offset: 0, index: 4)
        
        // Bounds computing
        let minBounds = LFloat4(Bounds.forBaseComputing.min, .infinity)
        let maxBounds = LFloat4(Bounds.forBaseComputing.max, -.infinity)
        
        let minXBuffer = try makeBoundsBuffer(starting: minBounds.x)
        let minYBuffer = try makeBoundsBuffer(starting: minBounds.y)
        let minZBuffer = try makeBoundsBuffer(starting: minBounds.z)
        
        let maxXBuffer = try makeBoundsBuffer(starting: maxBounds.x)
        let maxYBuffer = try makeBoundsBuffer(starting: maxBounds.y)
        let maxZBuffer = try makeBoundsBuffer(starting: maxBounds.z)
        
        computeCommandEncoder.setBuffer(minXBuffer, offset: 0, index: 5)
        computeCommandEncoder.setBuffer(minYBuffer, offset: 0, index: 6)
        computeCommandEncoder.setBuffer(minZBuffer, offset: 0, index: 7)
        
        computeCommandEncoder.setBuffer(maxXBuffer, offset: 0, index: 8)
        computeCommandEncoder.setBuffer(maxYBuffer, offset: 0, index: 9)
        computeCommandEncoder.setBuffer(maxZBuffer, offset: 0, index: 10)
        
        targetConstants.minXBuffer = minXBuffer
        targetConstants.minYBuffer = minYBuffer
        targetConstants.minZBuffer = minZBuffer
        
        targetConstants.maxXBuffer = maxXBuffer
        targetConstants.maxYBuffer = maxYBuffer
        targetConstants.maxZBuffer = maxZBuffer
        
        // -- Set pipeline state --
        computeCommandEncoder.setComputePipelineState(constantsBlitPipelineState)
        
        // Setup compute groups
        let threadgroups = makeGlyphMapKernelOutThreadgroups(
            for: unprocessedBuffer,
            state: constantsBlitPipelineState
        )
        let threadsPerThreadgroup = MTLSize(
            width: constantsBlitPipelineState.threadExecutionWidth,
            height: 1,
            depth: 1
        )
        
        // Dispatch the compute kernel and end encoding
        computeCommandEncoder.pushDebugGroup("[SG] Dispatch Blit")
        computeCommandEncoder.dispatchThreadgroups(
            threadgroups,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        computeCommandEncoder.popDebugGroup()
        
        // Finalize encoding
        computeCommandEncoder.endEncoding()
        
        return computeCommandEncoder
    }
}
