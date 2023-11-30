//  
//
//  Created on 11/24/23.
//  

import Foundation
import MetalKit
import MetalLinkHeaders

public enum ComputeError: Error {
    case missingFunction(String)
    case bufferCreationFailed
    case startupFailure
}

public class ConvertCompute: MetalLinkReader {
    public let link: MetalLink
    public init(link: MetalLink) { self.link = link }
    
    private let rawRenderName = "utf8ToUtf32Kernel"
    private lazy var rawRenderkernelFunction = library.makeFunction(name: rawRenderName)
    
    private let atlasRenderName = "utf8ToUtf32KernelAtlasMapped"
    private lazy var atlasRenderKernelFunction = library.makeFunction(name: atlasRenderName)
    
    private let layoutKernelName = "utf32GlyphMapLayout"
    private lazy var layoutKernelFunction = library.makeFunction(name: layoutKernelName)
    
    // Create a pipeline state from the kernel function, using the default name
    private func makeRawRenderPipelineState() throws -> MTLComputePipelineState {
        guard let rawRenderkernelFunction 
        else { throw ComputeError.missingFunction(rawRenderName) }
        return try device.makeComputePipelineState(function: rawRenderkernelFunction)
    }
    
    private func makeAtlasRenderPipelineState() throws -> MTLComputePipelineState {
        guard let atlasRenderKernelFunction
        else { throw ComputeError.missingFunction(atlasRenderName) }
        return try device.makeComputePipelineState(function: atlasRenderKernelFunction)
    }
    
    private func makeLayoutRenderPipelineState() throws -> MTLComputePipelineState {
        guard let layoutKernelFunction
        else { throw ComputeError.missingFunction(layoutKernelName) }
        return try device.makeComputePipelineState(function: layoutKernelFunction)
    }
    
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
    
    // Create an output buffer matching the GlyphMapKernelOut structure
    // MARK: NOTE / TAKE CARE / BE AWARE [Buffer size]
    // Check it out the length is div 4 so the end buffer is
    private func makeOutputBuffer(from inputBuffer: MTLBuffer) throws -> MTLBuffer {
        let safeSize = max(1, inputBuffer.length)
        let safeOutputBufferSize = safeSize * MemoryLayout<GlyphMapKernelOut>.stride
        guard let outputBuffer = device.makeBuffer(length: safeOutputBufferSize, options: [])
        else { throw ComputeError.bufferCreationFailed }
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

    // Give me .utf8 text data and I'll do weird things to a buffer and give it back.
    public func execute(
        inputData: NSData
    ) throws -> MTLBuffer {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        guard let computeCommandEncoder, let commandBuffer
        else { throw ComputeError.startupFailure }
        
        let inputUTF8TextDataBuffer = try makeInputBuffer(inputData)
        let outputUTF32ConversionBuffer = try makeOutputBuffer(from: inputUTF8TextDataBuffer)
        let computePipelineState = try makeRawRenderPipelineState()

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
    ) throws -> MTLBuffer {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        guard let computeCommandEncoder, let commandBuffer
        else { throw ComputeError.startupFailure }
        
        // MARK: -- Fire up atlas
        
        let inputUTF8TextDataBuffer = try makeInputBuffer(inputData)
        let outputUTF32ConversionBuffer = try makeOutputBuffer(from: inputUTF8TextDataBuffer)
        let atlasPipelineState = try makeAtlasRenderPipelineState()

        // Set the compute kernel's parameters
        computeCommandEncoder.setBuffer(inputUTF8TextDataBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(outputUTF32ConversionBuffer, offset: 0, index: 1)
        computeCommandEncoder.setBuffer(atlasBuffer, offset: 0, index: 2)
        
        // Pass the sizes of the buffer as constants
        var utf8BufferSize = inputUTF8TextDataBuffer.length
        computeCommandEncoder.setBytes(&utf8BufferSize, length: MemoryLayout<Int>.size, index: 3)
        
        var atlasBufferSize = atlasBuffer.length
        computeCommandEncoder.setBytes(&atlasBufferSize, length: MemoryLayout<Int>.size, index: 4)
        
        // Set the pipeline state
        computeCommandEncoder.setComputePipelineState(atlasPipelineState)
        
        // Calculate the number of threads and threadgroups
        // TODO: Explain why (boundsl, performance, et al), and make this better; this is probably off
        var threadGroupSize = MTLSize(width: atlasPipelineState.threadExecutionWidth, height: 1, depth: 1)
        var threadGroupsWidthCeil = (inputUTF8TextDataBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        var threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // Dispatch the compute kernel
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )
        
        // MARK: -- Fire up layout. Oh boy.
        let layoutPipelineState = try makeLayoutRenderPipelineState()
        computeCommandEncoder.setComputePipelineState(layoutPipelineState)
        
        threadGroupSize = MTLSize(width: layoutPipelineState.threadExecutionWidth, height: 1, depth: 1)
        threadGroupsWidthCeil = (inputUTF8TextDataBuffer.length + threadGroupSize.width - 1) / threadGroupSize.width
        threadGroupsPerGrid = MTLSize(width: threadGroupsWidthCeil, height: 1, depth: 1)
        
        // I guess we can reuse the set bytes and buffers and thread groups.. let's just hope, heh.
        computeCommandEncoder.dispatchThreadgroups(
            threadGroupsPerGrid,
            threadsPerThreadgroup: threadGroupSize
        )

        // Finalize encoding and commit the command buffer
        computeCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Houston we have a buffer. Maybe, this time. Let's see what happened.
        return outputUTF32ConversionBuffer
    }

    
    public func cast(
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
    
    public func makeString(
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
    
    public func makeGraphemeBasedString(
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


