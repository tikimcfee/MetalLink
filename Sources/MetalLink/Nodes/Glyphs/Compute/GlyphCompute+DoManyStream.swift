//
//  GlyphCompute+DoManyStream.swift
//  MetalLink
//
//  Created by Ivan Lugo on 11/3/24.
//

import Foundation
import MetalKit
import BitHandling
import MetalLinkHeaders
import Combine


// MARK: -- [Many]

public extension ConvertCompute {
    func searchGlyphs_Conc(
        in collection: GlyphCollection,
        with query: [CharacterHashType],
        collectionMatched: inout Bool,
        clearOnly: Bool
    ) throws {
// -------------------------------------
//        onDebugStart()
// -------------------------------------
        guard let commandBuffer = self.commandQueue.makeCommandBuffer()
        else { throw ComputeError.startupFailure }
        
        let (
            foundMatch,
              /*debugPointer, */
            _ /*encoder*/
        ) = try self.searchConstants(
            in: collection,
            with: query,
            clearOnly: clearOnly,
            using: commandBuffer
        )
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let checked = foundMatch.boundPointer(as: UInt.self, count: 1)
        collectionMatched = checked[0] == 1
// -------------------------------------
//        onDebugStop()
        
//         (0..<100).map { pointer[$0].getFlag(.matchesSearch) }.filter { $0 }
//         (0..<100).compactMap { pointer[$0].getFlag(.matchesSearch) }.filter { $0 }
//         (0..<100).filter { query.contains(pointer[$0].unicodeHash) }.compactMap { pointer[$0].unicodeHash.glyphComputeCharacter }
        
//        let checked = foundMatch.boundPointer(as: UInt.self, count: 1)
////        let debug = (0..<100).map { debugPointer[$0] }
//        if checked[0] == 1 {
//            let (count, pointer) = collection.instancePointerPair
//            
//            let hashes =     (0..<1000).compactMap { pointer[$0].unicodeHash }
//            let flags  =     (0..<1000).compactMap { pointer[$0].flags }
//            let characters = hashes.compactMap     { $0.glyphComputeCharacter }
//                        
//            print("Well, it worked!")
//        }
// -------------------------------------
    }
    
    private func onDebugStart(_ captureManager: MTLCaptureManager = .shared()) {
        do {
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = commandQueue
            captureDescriptor.destination = .developerTools
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            print(error)
        }
    }
    
    private func onDebugStop(_ captureManager: MTLCaptureManager = .shared()) {
        if captureManager.isCapturing {
            captureManager.stopCapture()
        }
    }
    
    func executeManyWithAtlas_Conc(
        in source: URL,
        atlas: MetalLinkAtlas
    ) -> EncodeResult? {
        guard let buffer = makeBuffer() else { return nil }
        guard let result = doEncode(with: buffer) else { return nil }
        guard let blit = doBlit(with: result) else { return nil }
        guard let rebuild = doRebuild(on: blit) else { return nil }
        return rebuild
        
        func makeBuffer() -> MTLBuffer? {
            do {
                var data: Data
                if source.isSupportedFileType {
                    data = try Data(
                        contentsOf: source,
                        options: [.alwaysMapped]
                    )
                    
                    if data.count == 0 {
                        data = "<empty-file>".data(using: .utf8)!
                    }
                } else {
                    data = """
                    Unsupported file type
                    \(source.path())
                    """.data(using: .utf8)!
                    }
                
                let maxSize = Int(1024.0 * 1024.0 * GlobalLiveConfig.store.preference.maxFileSizePerGridMegabytes)
                if data.count > maxSize {
                    print("Prefixing large file from full render: \(source.pathComponents.suffix(2)) - \(data.count.megabytes)")
                    data = data.prefix(maxSize)
                    print("New size: \(source.pathComponents.suffix(2)) - \(data.count.megabytes)")
                }
                
                let buffer = try self.makeInputBuffer(data)
                buffer.label = "Input graphemes \(source.lastPathComponent)"
                print("Input buffer length: \(source.pathComponents.suffix(2)) -- \(buffer.length)")
                
                return buffer
            } catch {
                print(error)
                return nil
            }
        }
        
        func doEncode(with buffer: MTLBuffer) -> EncodeResult? {
            do {
                // Setup the first atlas + layout encoder
                guard let commandBuffer = self.commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
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
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                // We're off to the races <3
                return mappedLayout
            } catch {
                print(error)
                return nil
            }
        }
        
        func doBlit(with result: EncodeResult) -> EncodeResult? {
            do {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
                switch result.blitEncoder {
                case .notSet:
                    // Create a new instance state to blit our glyph data into
                    guard result.finalCount > 0 else {
                        print("-- (Couldn't map; empty final count for: \(result.sourceURL)")
                        return nil
                    }
                    
                    let newState = try InstanceState(
                        link: self.link,
                        bufferSize: Int(Float(result.finalCount) * 1.5),
                        instanceBuilder: atlas.nodeCache.create
                    )
                    
                    // Setup the blitter which maps the unicode magic to the render magic
                    let blitEncoder = try self.setupCopyBlitCommandEncoder(
                        for: result.outputBuffer,
                        targeting: newState,
                        expectedCharacterCount: result.finalCount,
                        in: commandBuffer
                    )
                    result.blitEncoder = .set(blitEncoder, newState)
                    
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    return result
                case .set(_, _):
                    fatalError("this.. how!?")
                }
            } catch {
                print(error)
                return nil
            }
        }
        
        func doRebuild(on result: EncodeResult) -> EncodeResult? {
            switch result.blitEncoder {
            case .notSet:
                return nil
                
            case .set(_, let state):
                do {
                    state.constants.currentEndIndex = Int(result.finalCount)
                    let collection = try GlyphCollection(
                        link: self.link,
                        linkAtlas: atlas,
                        instanceState: state
                    )
                    collection.resetCollectionState()
                    result.collection = .built(collection)
                    return result
                } catch {
                    fatalError("-- What happen? Someone set us up a bomb?\n\(error)")
                }
            }
        }
    }
    
    func executeManyWithAtlas_Stream(
        atlas: MetalLinkAtlas
    ) -> (
        in: PassthroughSubject<URL, Never>,
        out: AnyPublisher<EncodeResult, Never>
    ) {
        
        let subject = PassthroughSubject<URL, Never>()
        
        let dataStream = subject
            .receive(on: WorkerPool.shared.nextConcurrentWorker())
            .compactMap { source in
                do {
                    var data: Data
                    if source.isSupportedFileType {
                        data = try Data(
                            contentsOf: source,
                            options: [.alwaysMapped]
                        )
                        
                        if data.count == 0 {
                            data = "<empty-file>".data(using: .utf8)!
                        }
                    } else {
                        data = """
                    Unsupported file type
                    \(source.path())
                    """.data(using: .utf8)!
                    }
                    
                    let maxSize = Int(1024.0 * 1024.0 * 2)
                    if data.count > maxSize {
                        print("Prefixing large file from full render: \(source.pathComponents.suffix(2)) - \(data.count.megabytes)")
                        data = data.prefix(maxSize)
                        print("New size: \(source.pathComponents.suffix(2)) - \(data.count.megabytes)")
                    }
                    
                    let buffer = try self.makeInputBuffer(data)
                    buffer.label = "Input graphemes \(source.lastPathComponent)"
                    print("Input buffer length: \(source.pathComponents.suffix(2)) -- \(buffer.length)")
                    
                    return (source, buffer)
                } catch {
                    print(error)
                    return nil
                }
            }
        
        let encodeStream = dataStream.compactMap { source, buffer in
            do {
                // Setup the first atlas + layout encoder
                guard let commandBuffer = self.commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
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
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                // We're off to the races <3
                return mappedLayout
            } catch {
                print(error)
                return nil
            }
        }
        
        let blitStream = encodeStream.compactMap { result -> EncodeResult? in
            do {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer()
                else { throw ComputeError.startupFailure }
                
                switch result.blitEncoder {
                case .notSet:
                    // Create a new instance state to blit our glyph data into
                    guard result.finalCount > 0 else {
                        print("-- (Couldn't map; empty final count for: \(result.sourceURL)")
                        return nil
                    }
                    
                    let newState = try InstanceState(
                        link: self.link,
                        bufferSize: Int(Float(result.finalCount) * 1.5),
                        instanceBuilder: atlas.nodeCache.create
                    )
                    
                    // Setup the blitter which maps the unicode magic to the render magic
                    let blitEncoder = try self.setupCopyBlitCommandEncoder(
                        for: result.outputBuffer,
                        targeting: newState,
                        expectedCharacterCount: result.finalCount,
                        in: commandBuffer
                    )
                    result.blitEncoder = .set(blitEncoder, newState)
                    
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    return result
                case .set(_, _):
                    fatalError("this.. how!?")
                }
            } catch {
                print(error)
                return nil
            }
        }
        
        let rebuildStream = blitStream.compactMap { result -> EncodeResult? in
            switch result.blitEncoder {
            case .notSet:
                return nil
                
            case .set(_, let state):
                do {
                    state.constants.currentEndIndex = Int(result.finalCount)
                    let collection = try GlyphCollection(
                        link: self.link,
                        linkAtlas: atlas,
                        instanceState: state
                    )
                    collection.resetCollectionState()
                    result.collection = .built(collection)
                    return result
                } catch {
                    fatalError("-- What happen? Someone set us up a bomb?\n\(error)")
                }
            }
        }
        //        subject.send(completion: .finished)
        
        let collection = rebuildStream
            .eraseToAnyPublisher()
        
        return (subject, collection)
    }
}
