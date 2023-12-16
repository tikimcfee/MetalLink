//  
//  GlyphCompute.swift
//  Created on 11/24/23.
//  

import Foundation
import MetalKit
import MetalLinkHeaders
import BitHandling

public enum ComputeRenderError: Error {
    case invalidUrl(URL)
}

public enum ComputeError: Error {
    case missingFunction(String)
    case bufferCreationFailed
    case commandBufferCreationFailed
    case startupFailure
    case compressionFailure
    
    case encodeError(URL)
}

public class ConvertCompute: MetalLinkReader {
    public let link: MetalLink
    public init(link: MetalLink) { self.link = link }
    
    private lazy var functions = ConvertComputeFunctions(link: link)
    
    // Give me .utf8 text data and I'll do weird things to a buffer and give it back.
    public func execute(
        inputData: Data
    ) throws -> MTLBuffer {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        guard let computeCommandEncoder, let commandBuffer
        else { throw ComputeError.startupFailure }
        
        let inputUTF8TextDataBuffer = try makeInputBuffer(inputData)
        let outputUTF32ConversionBuffer = try makeRawOutputBuffer(from: inputUTF8TextDataBuffer)
        let computePipelineState = try functions.makeRawRenderPipelineState()
        
        // Set the compute kernel's parameters
        computeCommandEncoder.setBuffer(inputUTF8TextDataBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(outputUTF32ConversionBuffer, offset: 0, index: 1)
        
        // Pass the size of the UTF-8 buffer as a constant
        var utf8BufferSize = inputUTF8TextDataBuffer.length
        computeCommandEncoder.setBytes(&utf8BufferSize, length: MemoryLayout<Int>.size, index: 2)
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        
        // Calculate the number of threads and threadgroups
        // TODO: Explain why (boundsl, performance, et al), and make this better; this is probably off
        let threadGroupSize = MTLSize(width: computePipelineState.threadExecutionWidth, height: 1, depth: 1)
        let threadGroupsWidthCeil = (inputUTF8TextDataBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        let threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        
        // Finalize encoding and commit the command buffer
        computeCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Houston we have a buffer.
        return outputUTF32ConversionBuffer
    }
    
    public func executeWithAtlasBuffer(
        inputData: Data,
        atlasBuffer: MTLBuffer
    ) throws -> (MTLBuffer, UInt32) {
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw ComputeError.startupFailure }
        
        let (
            outputUTF32ConversionBuffer,
            characterCountBuffer,
            _
        ) = try setupAtlasLayoutCommandEncoder(
            for: try makeInputBuffer(inputData),
            in: commandBuffer,
            atlasBuffer: atlasBuffer
        )
        
        commandBuffer.addCompletedHandler { handler in
            if let error = handler.error {
                print("""
                        -- Compute kernel Error --
                        \(error)
                        --------------------------
                      """)
            }
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

//         Houston we have a buffer. Maybe, this time. Let's see what happened.
        let finalCount = characterCountBuffer.boundPointer(as: UInt32.self, count: 1)
        return (outputUTF32ConversionBuffer, finalCount.pointee)
    }
    
    public func compressFreshMappedBuffer(
        unprocessedBuffer: MTLBuffer,
        expectedCount: UInt32
    ) throws -> MTLBuffer {
        let cleanedOutputBuffer = try makeCleanedOutputBuffer(length: expectedCount)
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let compressionPipelineState = try functions.makeCompressionRenderPipelineState()
        guard let computeCommandEncoder, let commandBuffer
        else { throw ComputeError.startupFailure }
        
        // MARK: -- Compressenator
        computeCommandEncoder.setBuffer(unprocessedBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(cleanedOutputBuffer, offset: 0, index: 1)
        
        var unprocessedSize: Int = unprocessedBuffer.length
        computeCommandEncoder.setBytes(&unprocessedSize, length: Int.memSize, index: 2)
        
        var cleanBufferCount: Int = Int(expectedCount)
        computeCommandEncoder.setBytes(&cleanBufferCount, length: Int.memSize, index: 3)
        
        computeCommandEncoder.setComputePipelineState(compressionPipelineState)
        
        let threadgroups = makeGlyphMapKernelOutThreadgroups(
            for: unprocessedBuffer,
            state: compressionPipelineState
        )
        let threadsPerThreadgroup = MTLSize(
            width: compressionPipelineState.threadExecutionWidth,
            height: 1,
            depth: 1
        )
        
        // Dispatch the compute kernel
        computeCommandEncoder.dispatchThreadgroups(
            threadgroups,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        
        // Finalize encoding and commit the command buffer
        computeCommandEncoder.endEncoding()
        commandBuffer.addCompletedHandler { handler in
            if let error = handler.error {
                print("""
                        -- Compute kernel Error --
                        \(error)
                        --------------------------
                      """)
            }
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return cleanedOutputBuffer
    }
}

// MARK: - Kernel functions + Pipeline states

private class ConvertComputeFunctions: MetalLinkReader {
    let link: MetalLink
    init(link: MetalLink) { self.link = link }
    
    let rawRenderName = "utf8ToUtf32Kernel"
    lazy var rawRenderkernelFunction = library.makeFunction(name: rawRenderName)
    
    let atlasRenderName = "utf8ToUtf32KernelAtlasMapped"
    lazy var atlasRenderKernelFunction = library.makeFunction(name: atlasRenderName)
    
    let layoutKernelName = "utf32GlyphMapLayout"
    lazy var layoutKernelFunction = library.makeFunction(name: layoutKernelName)
    
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

// MARK: - Default buffer builders

extension ConvertCompute {
    // Create a Metal buffer from the Data object
    func makeInputBuffer(_ data: Data) throws -> MTLBuffer {
        #if os(iOS)
        let mode = MTLResourceOptions.storageModeShared
        #else
        let mode = MTLResourceOptions.storageModeManaged
        #endif
        
        let buffer: MTLBuffer? = data.withUnsafeBytes { rawBufferPointer in
            if let base = rawBufferPointer.baseAddress {
                return device.makeBuffer(
                    bytes: base,
                    length: data.count,
                    options: [mode]
                )
            } else {
                return nil
            }
        }
        
        guard let buffer else {
            throw ComputeError.bufferCreationFailed
        }
        
        return buffer
    }
    
    // Teeny buffer to write total character count
    func makeCharacterCountBuffer(
        starting: UInt32
    ) throws -> MTLBuffer {
        let data = withUnsafeBytes(of: starting) { Data($0) }
        
        guard let buffer = device.loadToMTLBuffer(data: data)
        else { throw ComputeError.bufferCreationFailed }
        
        return buffer
    }
    
    func makeBoundsBuffer(
        starting: Float
    ) throws -> MTLBuffer {
        let data = withUnsafeBytes(of: starting) { Data($0) }
        
        guard let buffer = device.loadToMTLBuffer(data: data)
        else { throw ComputeError.bufferCreationFailed }
        
        return buffer
    }
    
    // Create an output buffer matching the GlyphMapKernelOut structure
    func makeRawOutputBuffer(from inputBuffer: MTLBuffer) throws -> MTLBuffer {
        let safeSize = max(1, inputBuffer.length)
        let safeOutputBufferSize = safeSize * MemoryLayout<GlyphMapKernelOut>.stride
        guard let outputBuffer = device.makeBuffer(
            length: safeOutputBufferSize,
            options: [.storageModeShared]
        )
        else { throw ComputeError.bufferCreationFailed }
        outputBuffer.label = "Output :: \(inputBuffer.label ?? "<no input name>")"
        return outputBuffer
    }
    
    // Create an output with an expected output size
    // TODO: This can make directly to instanced constants hnnnggh
    func makeCleanedOutputBuffer(length: UInt32) throws -> MTLBuffer {
        let safeSize = max(1, length)
        let outputBuffer = try link.makeBuffer(
            of: GlyphMapKernelOut.self,
            count: Int(safeSize)
        )
        return outputBuffer
    }
    
    private func roundUp(
        number: UInt32,
        toMultipleOf multiple: UInt32
    ) -> UInt32 {
      let remainder = number % multiple
      if (remainder == 0) {
          return number;
      } else {
          return number + multiple - remainder
      }
    }
    
    public func makeGraphemeAtlasBuffer(
        size: Int
    ) throws -> MTLBuffer {
        let length = size * MemoryLayout<GlyphMapKernelAtlasIn>.stride
        guard let metalBuffer = device.makeBuffer(
            length: length,
            options: [ /*.cpuCacheModeWriteCombined*/ ] // TODO: is this a safe performance trick?
        ) else { throw ComputeError.bufferCreationFailed }
        metalBuffer.label = "Grapheme Atlas Buffer, l=\(length)"
        return metalBuffer
    }
    
    private func makeGlyphMapKernelOutThreadgroups(
        for buffer: MTLBuffer,
        state: MTLComputePipelineState
    ) -> MTLSize {
        let bufferElementCount = buffer.length

        let threadgroupWidth = state.threadExecutionWidth - 1
        let threadgroupsNeeded = (bufferElementCount + threadgroupWidth - 1)
                               / (threadgroupWidth)
        
        return MTLSize(
            width: threadgroupsNeeded,
            height: 1,
            depth: 1
        )
    }
}

// MARK: - Pointer helpers, String Builders

public extension ConvertCompute {
    func cast(
        _ buffer: MTLBuffer
    ) -> (UnsafeMutablePointer<GlyphMapKernelOut>, Int) {
        let numberOfElements = buffer.length / MemoryLayout<GlyphMapKernelOut>.stride
        return (
            buffer.contents().bindMemory(
                to: GlyphMapKernelOut.self,
                capacity: numberOfElements
            ),
            numberOfElements
        )
    }
    
    func makeString(
        from pointer: UnsafeMutablePointer<GlyphMapKernelOut>,
        count: Int
    ) -> String {
        // TODO: Is there a safe way to initialize with a starting block size?
        var scalarView = String.UnicodeScalarView()
        for index in 0..<count {
            let glyph = pointer[index] // Access each GlyphMapKernelOut
            // Process 'glyph' as needed
            guard glyph.codePoint > 0,
                  let scalar = UnicodeScalar(glyph.codePoint)
            else { continue }
            scalarView.append(scalar)
        }
        let scalarString = String(scalarView)
        return scalarString
    }
    
    func makeGraphemeBasedString(
        from pointer: UnsafeMutablePointer<GlyphMapKernelOut>,
        count: Int
    ) -> String {
        let allUnicodeScalarsInView: String.UnicodeScalarView =
            (0..<count)
                .lazy
                .map { pointer[$0].allSequentialScalars }
                .filter { !$0.isEmpty }
                .map { scalarList in
                    scalarList.lazy.compactMap { scalar in
                        UnicodeScalar(scalar)
                    }
                }
                .reduce(into: String.UnicodeScalarView()) { view, scalars in
                    view.append(contentsOf: scalars)
                }
        let manualGraphemeString = String(allUnicodeScalarsInView)
        return manualGraphemeString
    }
}

// MARK: - Glyph Magic

public extension ConvertCompute {
    typealias InputBufferList = ConcurrentArray<(URL, MTLBuffer)>
    typealias ErrorList = ConcurrentArray<Error>
    typealias ResultList = ConcurrentArray<EncodeResult>
    
    enum Event {
        case bufferMapped(String)
        case layoutEncoded(String)
        case copyEncoded(String)
        case collectionReady(String)
        
        var name: String {
            switch self {
            case let .bufferMapped(name),
                let .layoutEncoded(name),
                let .copyEncoded(name),
                let .collectionReady(name):
                return name
            }
        }
    }
    
    func executeManyWithAtlas(
        sources: [URL],
        atlas: MetalLinkAtlas,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) throws -> [EncodeResult] {
        let errors = ConcurrentArray<Error>()

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
        
        return results.values
    }
    
    func dispatchMapToBuffers(
        sources: [URL],
        errors: ErrorList,
        onEvent: @escaping (Event) -> Void = { _ in }
    ) -> InputBufferList {
        let loadedData = InputBufferList()
        let dispatchGroup = DispatchGroup()
        
        for source in sources {
            dispatchGroup.enter()
            WorkerPool.shared.nextWorker().async { [makeInputBuffer] in
                do {
                    var data = try Data(
                        contentsOf: source,
                        options: [.alwaysMapped]
                    )
                    if data.count == 0 {
                        data = String("<empty-file>").data(using: .utf8)!
                    }
                    if data.count > 10_000_000 {
                        print("Skipping source URL: \(source), data is: \(data.count)")
                        return
                    }
                    
                    let buffer = try makeInputBuffer(data)
                    buffer.label = "Input grapheme \(source.lastPathComponent)"
                    loadedData.append((source, buffer))
                    
                    onEvent(.bufferMapped(source.lastPathComponent))
                } catch {
                    errors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()
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
        let dispatchGroup = DispatchGroup()
        for result in results.values {
            switch result.blitEncoder {
            case .notSet:
                break

            case .set(_, let state):
                dispatchGroup.enter()
                WorkerPool.shared.nextWorker().async { [link] in
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
                    dispatchGroup.leave()
                }
            }
        }
        dispatchGroup.wait()
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
        let starting = UInt32(targetConstants.instanceBufferCount)
        let instanceCountBuffer = try makeCharacterCountBuffer(starting: starting)
        computeCommandEncoder.setBuffer(instanceCountBuffer, offset: 0, index: 4)
        
        // We're gonna try computing bounds 'cause.. why not. Sure.
        let minXBuffer = try makeBoundsBuffer(starting: .infinity)
        let minYBuffer = try makeBoundsBuffer(starting: .infinity)
        let minZBuffer = try makeBoundsBuffer(starting: .infinity)
        
        let maxXBuffer = try makeBoundsBuffer(starting: -.infinity)
        let maxYBuffer = try makeBoundsBuffer(starting: -.infinity)
        let maxZBuffer = try makeBoundsBuffer(starting: -.infinity)
        
        computeCommandEncoder.setBuffer(minXBuffer, offset: 0, index: 5)
        computeCommandEncoder.setBuffer(minYBuffer, offset: 0, index: 6)
        computeCommandEncoder.setBuffer(minZBuffer, offset: 0, index: 7)
        
        computeCommandEncoder.setBuffer(maxXBuffer, offset: 0, index: 8)
        computeCommandEncoder.setBuffer(maxYBuffer, offset: 0, index: 9)
        computeCommandEncoder.setBuffer(maxZBuffer, offset: 0, index: 10)
        
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
        computeCommandEncoder.pushDebugGroup("[SG] - Dipsatch initial atlas map")
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        computeCommandEncoder.popDebugGroup()
        
        // MARK: -- Fire up layout. Oh boy.
        let layoutPipelineState = try functions.makeLayoutRenderPipelineState()
        computeCommandEncoder.setComputePipelineState(layoutPipelineState)
        
        // I guess we can reuse the set bytes and buffers and thread groups.. let's just hope, heh.
        computeCommandEncoder.pushDebugGroup("[SG] - Dispating layout")
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
}

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
