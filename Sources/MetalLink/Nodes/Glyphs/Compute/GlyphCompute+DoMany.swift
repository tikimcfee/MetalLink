//  
//
//  Created on 12/17/23.
//  

import Foundation
import MetalKit
import BitHandling

// MARK: -- [Many]

public extension ConvertCompute {
    func executeManyWithAtlas(
        sources: [URL],
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> [EncodeResult] {
        let errors = ConcurrentArray<Error>()
        
//        try startCapture()

        // MARK: ------ [Many Buffer build]
        // Setup buffers from CPU side...
        let loadedData = dispatchMapToBuffers(
            sources: sources,
            errors: errors,
            onEvent: onEvent
        )
        
        // MARK: ------ [Many Atlas layout]
        // Map all of them to atlas mapping and layout encoding
        let results = try encodeLayout(
            for: loadedData,
            in: commandQueue,
            atlas: atlas,
            errors: errors,
            onEvent: onEvent
        )
        
        // MARK: ------ [Many Copy Blit]
        // TODO: just process on CPU maybe?... could be parallel too... =(
        try encodeConstantsBlit(
            into: results,
            in: commandQueue,
            atlas: atlas,
            errors: errors,
            onEvent: onEvent
        )

        // MARK: ----- [Many Grid Rebuild]
        // Iterate again and rebuild all the instance state objects.
        // The more we do this, the more it gets closers to all being GPU...
        dispatchCollectionRebuilds(
            for: results,
            atlas: atlas,
            onEvent: onEvent
        )
        
//        stopCapture()
        
        return results.values
    }
    
    func dispatchMapToBuffers(
        sources: [URL],
        errors: ErrorList,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) -> InputBufferList {
        let loadedData = InputBufferList()
//        let dispatchGroup = DispatchGroup()
        
        for source in sources {
//            dispatchGroup.enter()
//            WorkerPool.shared.nextWorker().async { [makeInputBuffer] in
                do {
                    var data = try Data(
                        contentsOf: source,
                        options: [.alwaysMapped]
                    )
                    
                    if data.count == 0 {
                        data = String("<empty-file>").data(using: .utf8)!
                    }
                    
//                    let maxSize = 1024 * 1024 * 8
//                    if data.count > maxSize {
//                        print("Skipping large file in full render: \(source.pathComponents.suffix(2)) \(data.count.megabytes)")
//                        continue
//                    }
                    
                    let buffer = try makeInputBuffer(data)
                    buffer.label = "Input graphemes \(source.lastPathComponent)"
                    loadedData.append((source, buffer))
                    
                    onEvent(.bufferMapped(source.lastPathComponent))
                } catch {
                    errors.append(error)
                }
//                dispatchGroup.leave()
//            }
        }
//        dispatchGroup.wait()
        return loadedData
    }
    
    func encodeLayout(
        for loadedData: InputBufferList,
        in queue: MTLCommandQueue,
        atlas: MetalLinkAtlas,
        errors: ErrorList,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> ResultList {
        // All atlas encoders are ready; commit the command buffer and wait for it to complete
        guard var commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.startupFailure }
        
        let results = ResultList()
        commandBuffer.pushDebugGroup("[SG] Root Layout Encode Buffer")
        var unprocessedBuffers = 0
        for (source, buffer) in loadedData.values {
            if unprocessedBuffers >= link.DefaultQueueMaxUnprocessedBuffers {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                guard let newBuffer = commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
                commandBuffer = newBuffer
                unprocessedBuffers = 0
            }
            
            onNext(source, buffer)
            unprocessedBuffers += 1
        }
        commandBuffer.popDebugGroup()
        if unprocessedBuffers > 0 {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        func onNext(
            _ source: URL,
            _ buffer: MTLBuffer
        ) {
            do {
                // Setup the first atlas + layout encoder
                let (
                    outputUTF32ConversionBuffer,
                    characterCountBuffer,
                    computeCommandEncoder
                ) = try self.setupAtlasLayoutCommandEncoder(
                    for: buffer,
                    in: commandBuffer,
                    atlasBuffer: atlas.currentBuffer
                )
                
                computeCommandEncoder.insertDebugSignpost("[SG] Created Atlas Layout Encoder - \(source.lastPathComponent)")
                
                // Setup the result (this is weird but it made sense at the time)
                let mappedLayout = EncodeResult(
                    sourceURL: source,
                    outputBuffer: outputUTF32ConversionBuffer,
                    characterCountBuffer: characterCountBuffer,
                    sourceEncoder: computeCommandEncoder
                )
                
                // We're off to the races <3
                results.append(mappedLayout)
                
                onEvent(.layoutEncoded(source.lastPathComponent))
            } catch {
                errors.append(error)
            }
        }

        return results
    }
    
    func encodeConstantsBlit(
        into results: ResultList,
        in queue: MTLCommandQueue,
        atlas: MetalLinkAtlas,
        errors: ErrorList,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws {
        guard var commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.startupFailure }
        
        var unprocessedBuffers = 0
        for result in results.values {
            if unprocessedBuffers >= link.DefaultQueueMaxUnprocessedBuffers {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                guard let newBuffer = commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
                commandBuffer = newBuffer
                unprocessedBuffers = 0
            }
            
            onNext(result)
            unprocessedBuffers += 1
        }
        
        if unprocessedBuffers > 0 {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        func onNext(_ result: EncodeResult) {
            switch result.blitEncoder {
            case .notSet:
                // Create a new instance state to blit our glyph data into
                guard result.finalCount > 0 else {
                    print("-- (Couldn't map; empty final count for: \(result.sourceURL)")
                    return
                }
                
                do {
                    let newState = try InstanceState(
                        link: link,
                        bufferSize: Int(Float(result.finalCount) * 1.5),
                        instanceBuilder: atlas.nodeCache.create
                    )
                    
                    // Setup the blitter which maps the unicode magic to the render magic
                    let blitEncoder = try setupCopyBlitCommandEncoder(
                        for: result.outputBuffer,
                        targeting: newState,
                        expectedCharacterCount: result.finalCount,
                        in: commandBuffer
                    )
                    result.blitEncoder = .set(blitEncoder, newState)
                    
                    onEvent(.copyEncoded(result.sourceURL.lastPathComponent))
                } catch {
                    errors.append(error)
                }

            case .set(_, _):
                fatalError("this.. how!?")
            }
        }
    }
    
    func dispatchCollectionRebuilds(
        for results: ResultList,
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) {
//        let dispatchGroup = DispatchGroup()
        for result in results.values {
            switch result.blitEncoder {
            case .notSet:
                break

            case .set(_, let state):
//                dispatchGroup.enter()
//                WorkerPool.shared.nextWorker().async { [link] in
                    do {
                        state.constants.currentEndIndex = Int(result.finalCount)
                        let collection = try GlyphCollection(
                            link: link,
                            linkAtlas: atlas,
                            instanceState: state
                        )
                        collection.resetCollectionState()
                        result.collection = .built(collection)
                        
                        onEvent(.collectionReady(result.sourceURL.lastPathComponent))
                    } catch {
                        fatalError("-- What happen? Someone set us up a bomb?\n\(error)")
                    }
//                    dispatchGroup.leave()
//                }
            }
        }
//        dispatchGroup.wait()
    }
}
