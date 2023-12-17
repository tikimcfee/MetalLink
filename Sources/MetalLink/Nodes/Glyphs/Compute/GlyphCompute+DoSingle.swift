//  
//
//  Created on 12/17/23.
//  

import Foundation
import Foundation
import MetalKit

// MARK: -- Single

public extension ConvertCompute {
    func executeDataWithAtlas(
        name: String,
        source: Data,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> EncodeResult {
        var data = source
        if data.count == 0 {
            data = String("<empty-file>").data(using: .utf8)!
        }
        let buffer = try makeInputBuffer(data)
        buffer.label = "Input grapheme raw data: \(name)"
        
        let temporaryURL = URL(string: "rawGrapheme://\(name)")!
        
        // Map it to atlas mapping and layout encoding
        let result = try encodeSingleLayout(
            for: (temporaryURL, buffer),
            in: commandQueue,
            atlas: atlas,
            onEvent: onEvent
        )
        
        // Copy the stuff
        try encodeSingleCopy(
            result: result,
            atlas: atlas,
            onEvent: onEvent
        )
        
        // Rebuild the collection
        try rebuildResult(
            result,
            atlas: atlas,
            onEvent: onEvent
        )
        
        return result
    }
    
    func executeSingleWithAtlas(
        source: URL,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> EncodeResult {
        // Setup buffer from CPU side...
        let loadedData = try mapToBuffer(
            source: source,
            onEvent: onEvent
        )
        
        // Map it to atlas mapping and layout encoding
        let result = try encodeSingleLayout(
            for: (source, loadedData),
            in: commandQueue,
            atlas: atlas,
            onEvent: onEvent
        )
        
        // Copy the stuff
        try encodeSingleCopy(
            result: result,
            atlas: atlas,
            onEvent: onEvent
        )
        
        // Rebuild the collection
        try rebuildResult(
            result,
            atlas: atlas,
            onEvent: onEvent
        )
        
        return result
    }
    
    func mapToBuffer(
        source: URL,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> MTLBuffer {
        var data = try Data(
            contentsOf: source,
            options: [.alwaysMapped]
        )
        if data.count == 0 {
            data = String("<empty-file>").data(using: .utf8)!
        }
        
        let buffer = try makeInputBuffer(data)
        buffer.label = "Input grapheme \(source.lastPathComponent)"
        
        onEvent(.bufferMapped(source.lastPathComponent))
        
        return buffer
    }
    
    func encodeSingleLayout(
        for loadedData: (source: URL, buffer: MTLBuffer),
        in queue: MTLCommandQueue,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> EncodeResult {
        // All atlas encoders are ready; commit the command buffer and wait for it to complete
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.startupFailure }
        
        commandBuffer.pushDebugGroup("[SG] Root Single-Layout Encode Buffer")
        
        // Create an EncodeResult from the encoded command
        let (
            outputUTF32ConversionBuffer,
            characterCountBuffer,
            computeCommandEncoder
        ) = try self.setupAtlasLayoutCommandEncoder(
            for: loadedData.buffer,
            in: commandBuffer,
            atlasBuffer: atlas.currentBuffer
        )
        let mappedLayout = EncodeResult(
            sourceURL: loadedData.source,
            outputBuffer: outputUTF32ConversionBuffer,
            characterCountBuffer: characterCountBuffer,
            sourceEncoder: computeCommandEncoder
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        commandBuffer.popDebugGroup()
        
        onEvent(.layoutEncoded(loadedData.source.lastPathComponent))
        
        return mappedLayout
    }
    
    func encodeSingleCopy(
        result: EncodeResult,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws {
        switch result.blitEncoder {
        case .notSet:
            try doSet()
        case .set(_, _):
            fatalError("this.. how!?")
        }
        
        func doSet() throws {
            // Create a new instance state to blit our glyph data into
            let finalCount = result.finalCount
            guard finalCount > 0 else {
                print("-- (Couldn't map; empty final count for: \(result.sourceURL)")
                return
            }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer()
            else { throw ComputeError.startupFailure }
            
            let newState = try InstanceState(
                link: link,
                bufferSize: Int(Float(result.finalCount) * 1.5),
                instanceBuilder: atlas.nodeCache.create
            )
            
            commandBuffer.pushDebugGroup("[SG] Single Buffer Copy")
            
            // Setup the blitter which maps the unicode magic to the render magic
            let blitEncoder = try setupCopyBlitCommandEncoder(
                for: result.outputBuffer,
                targeting: newState,
                expectedCharacterCount: finalCount,
                in: commandBuffer
            )
            result.blitEncoder = .set(blitEncoder, newState)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            commandBuffer.popDebugGroup()
            
            onEvent(.copyEncoded(result.sourceURL.lastPathComponent))
        }
    }
    
    func rebuildResult(
        _ result: EncodeResult,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws {
        switch result.blitEncoder {
        case .set(_, let state):
            state.constants.currentEndIndex = Int(result.finalCount)
            let collection = try GlyphCollection(
                link: link,
                linkAtlas: atlas,
                instanceState: state
            )
            collection.resetCollectionState()
            result.collection = .built(collection)
            
            onEvent(.collectionReady(result.sourceURL.lastPathComponent))
            
        case .notSet:
            print("<!> Result had no encoder set: \(result)")
        }
    }
}

