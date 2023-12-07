//  
//  GlyphCompute.swift
//  Created on 11/24/23.
//  

import Foundation
import MetalKit
import MetalLinkHeaders

public enum ComputeError: Error {
    case missingFunction(String)
    case bufferCreationFailed
    case startupFailure
    case compressionFailure
}

public class ConvertCompute: MetalLinkReader {
    public let link: MetalLink
    public init(link: MetalLink) { self.link = link }
    
    private lazy var functions = ConvertComputeFunctions(link: link)
    
    // Give me .utf8 text data and I'll do weird things to a buffer and give it back.
    public func execute(
        inputData: NSData
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
    
    // Give me .utf8 text data and an atlas buffer and I'll do even weirder things
    public func executeWithAtlas(
        inputData: NSData,
        atlasBuffer: MTLBuffer
    ) throws -> (MTLBuffer, UInt32) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        guard let computeCommandEncoder, let commandBuffer
        else { throw ComputeError.startupFailure }
        
        // MARK: -- Fire up atlas
        
        let inputUTF8TextDataBuffer = try makeInputBuffer(inputData)
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
        
        // And also pass a mutable count to tally up the total hashed up characters. This will be used to setup
        // a final output buffer.
        let characterCountBuffer = try makeCharacterCountBuffer()
        computeCommandEncoder.setBuffer(characterCountBuffer, offset: 0, index: 5)
        
        // Set the pipeline state
        computeCommandEncoder.setComputePipelineState(atlasPipelineState)
        
        // Calculate the number of threads and threadgroups
        // TODO: Explain why (boundsl, performance, et al), and make this better; this is probably off
        let threadGroupSize = MTLSize(width: atlasPipelineState.threadExecutionWidth, height: 1, depth: 1)
        let threadGroupsWidthCeil = (inputUTF8TextDataBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        let threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        
        // MARK: -- Fire up layout. Oh boy.
        let layoutPipelineState = try functions.makeLayoutRenderPipelineState()
        computeCommandEncoder.setComputePipelineState(layoutPipelineState)
        
        // I guess we can reuse the set bytes and buffers and thread groups.. let's just hope, heh.
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
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

        // Houston we have a buffer. Maybe, this time. Let's see what happened.
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
        
        // MARK: -- Fire up the compressenator
        computeCommandEncoder.setBuffer(unprocessedBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(cleanedOutputBuffer, offset: 0, index: 1)
        
        computeCommandEncoder.setComputePipelineState(compressionPipelineState)
        
        let threadGroupSize = MTLSize(width: compressionPipelineState.threadExecutionWidth, height: 1, depth: 1)
        let threadGroupsWidthCeil = (unprocessedBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        let threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
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
}

// MARK: - Default buffer builders

extension ConvertCompute {
    // Create a Metal buffer from the Data object
    private func makeInputBuffer(_ data: NSData) throws -> MTLBuffer {
        guard let metalBuffer = device.makeBuffer(
            bytes: data.bytes,
            length: data.count,
            options: []
        )
        else { throw ComputeError.bufferCreationFailed }
        return metalBuffer
    }
    
    // Teeny buffer to write total character count
    private func makeCharacterCountBuffer() throws -> MTLBuffer {
        guard let metalBuffer = try? link.makeBuffer(of: UInt32.self, count: 1)
        else { throw ComputeError.bufferCreationFailed }
        
        return metalBuffer
    }
    
    // Create an output buffer matching the GlyphMapKernelOut structure
    private func makeRawOutputBuffer(from inputBuffer: MTLBuffer) throws -> MTLBuffer {
        let safeSize = max(1, inputBuffer.length)
        let safeOutputBufferSize = safeSize * MemoryLayout<GlyphMapKernelOut>.stride
        guard let outputBuffer = device.makeBuffer(
            length: safeOutputBufferSize,
            options: []
        )
        else { throw ComputeError.bufferCreationFailed }
        return outputBuffer
    }
    
    // Create an output with an expected output size
    // TODO: This can make directly to instanced constants hnnnggh
    private func makeCleanedOutputBuffer(length: UInt32) throws -> MTLBuffer {
        let safeSize = max(1, length)
        let outputBuffer = try link.makeBuffer(
            of: GlyphMapKernelOut.self,
            count: Int(safeSize)
        )
        return outputBuffer
    }
    
    public func makeGraphemeAtlasBuffer(
        size: Int
    ) throws -> MTLBuffer {
        guard let metalBuffer = device.makeBuffer(
            length: size * MemoryLayout<GlyphMapKernelAtlasIn>.stride,
            options: [ /*.cpuCacheModeWriteCombined*/ ] // TODO: is this a safe performance trick?
        ) else { throw ComputeError.bufferCreationFailed }
        return metalBuffer
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
                    scalarList.lazy.map { scalar in
                        UnicodeScalar(scalar)!
                    }
                }
                .reduce(into: String.UnicodeScalarView()) { view, scalars in
                    view.append(contentsOf: scalars)
                }
        let manualGraphemeString = String(allUnicodeScalarsInView)
        return manualGraphemeString
    }
}
