//  
//
//  Created on 12/17/23.
//  

import Foundation
import MetalKit

public extension ConvertCompute {
    // Give me .utf8 text data and I'll do weird things to a buffer and give it back.
    func execute(
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
    
    func executeWithAtlasBuffer(
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
    
    func compressFreshMappedBuffer(
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
