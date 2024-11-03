//  
//
//  Created on 12/17/23.
//  

import Foundation
import MetalKit
import BitHandling
import MetalLinkHeaders

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
    // TODO: --- Memory explosion, the big one
    // We take every 8-bit run and explode into by many hundreds for the `GlyphMapKernelOut`.
    // That's gross. Instead, we should make a buffer for just the hashes of the file length,
    // and use it as an intermediary before getting to the kernel out.
    // --------------------------------------------------
    // [From STTextView]
    // <Making output buffer: [6.268 MB] -> [1404.053 MB]>
    // [After removing some fields from KernelOut]
    // <Making output buffer: [6.268 MB] -> [1002.895 MB]>
    // --------------------------------------------------
    func makeRawOutputBuffer(from inputBuffer: MTLBuffer) throws -> MTLBuffer {
        let safeSize = max(1, inputBuffer.length)
        let safeOutputBufferSize = safeSize * MemoryLayout<GlyphMapKernelOut>.stride
        print("<Making output buffer: \(inputBuffer.length.megabytes) -> \(safeOutputBufferSize.megabytes)>")
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
    
    public func roundUp(
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
    
    public func makeGlyphMapKernelOutThreadgroups(
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
