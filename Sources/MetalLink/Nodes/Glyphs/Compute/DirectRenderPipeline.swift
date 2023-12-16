//  
//
//  Created on 12/14/23.
//  

import Foundation
import MetalKit
import MetalLinkHeaders
import BitHandling

public struct FileWatchRenderer: MetalLinkReader {
    public let link: MetalLink
    public var atlas: MetalLinkAtlas
    public let compute: ConvertCompute
    public let sourceUrl: URL
    
    public init(
        link: MetalLink,
        atlas: MetalLinkAtlas,
        compute: ConvertCompute,
        sourceUrl: URL
    ) {
        self.link = link
        self.atlas = atlas
        self.compute = compute
        self.sourceUrl = sourceUrl
    }

    public func regenerateCollectionForSource() throws -> GlyphCollection {
        
        let buffer = try readUrlIntoBuffer()
        let encodeResult = try encodeLayout(for: buffer)
        try encodeBlit(for: encodeResult)
        try rebuildCollection(for: encodeResult)
        switch encodeResult.collection {
        case .built(let result):
            return result
        case .notBuilt:
            print("""
            XXX - Encoding pipeline failed for url: \(sourceUrl), returning default empty collection. Expect bad things.
            """)
            return try GlyphCollection(link: link, linkAtlas: atlas)
        }
    }
}

private extension FileWatchRenderer {
    // MARK: [ 1 ] - Read source into buffer
    func readUrlIntoBuffer() throws -> MTLBuffer {
        let data: Data
        if sourceUrl.isDirectory {
            data = "<directory-url:\(sourceUrl)>".data(using: .utf8)!
        } else {
            data = try Data(contentsOf: sourceUrl, options: [.alwaysMapped])
        }
        
        let buffer = try compute.makeInputBuffer(data)
        buffer.label = "Input grapheme \(sourceUrl.lastPathComponent)"
        return buffer
    }
    
    // MARK: [ 2 ] - Read source into buffer
    func encodeLayout(for buffer: MTLBuffer) throws -> EncodeResult {
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.commandBufferCreationFailed }
        
        // Setup the first atlas + layout encoder
        let (
            outputUTF32ConversionBuffer,
            characterCountBuffer,
            computeCommandEncoder
        ) = try compute.setupAtlasLayoutCommandEncoder(
            for: buffer,
            in: commandBuffer,
            atlasBuffer: atlas.currentBuffer
        )
        
        // Setup the result (this is weird but it made sense at the time)
        let mappedLayout = EncodeResult(
            sourceURL: sourceUrl,
            outputBuffer: outputUTF32ConversionBuffer,
            characterCountBuffer: characterCountBuffer,
            sourceEncoder: computeCommandEncoder
        )
        
        // Commit our buffer and schedule it
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return mappedLayout
    }
    
    func encodeBlit(for result: EncodeResult) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.commandBufferCreationFailed }
        
        switch result.blitEncoder {
        case .notSet:
            // Create a new instance state to blit our glyph data into
            guard result.finalCount > 0 else {
                print("-- (Couldn't map; empty final count for: \(result.sourceURL)")
                return
            }
            
            let newState = try InstanceState(
                link: link,
                bufferSize: Int(Float(result.finalCount) * 1.5),
                instanceBuilder: atlas.nodeCache.create
            )
            
            // Setup the blitter which maps the unicode magic to the render magic
            let blitEncoder = try compute.setupCopyBlitCommandEncoder(
                for: result.outputBuffer,
                targeting: newState,
                expectedCharacterCount: result.finalCount,
                in: commandBuffer
            )
            result.blitEncoder = .set(blitEncoder, newState)

        case .set(_, _):
            print("""
            ----
            ---- Invalid encode state for: \(sourceUrl)
            ----
            """)
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func rebuildCollection(for result: EncodeResult) throws {
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
            
        case .notSet:
            break
        }
    }
}
