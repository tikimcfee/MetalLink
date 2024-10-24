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
    case commandEncoderFailure
    case compressionFailure
    
    case encodeError(URL)
}

public class ConvertCompute: MetalLinkReader {
    public typealias InputBufferList = ConcurrentArray<(URL, MTLBuffer)>
    public typealias ErrorList = ConcurrentArray<Error>
    public typealias ResultList = ConcurrentArray<EncodeResult>
    
    public let link: MetalLink
    public let commandQueue: MTLCommandQueue
    public init(link: MetalLink) {
        self.link = link
        self.commandQueue = link.device.makeCommandQueue()!
        self.commandQueue.label = "GlyphComputeQueue"
    }
    
    internal lazy var functions = ConvertComputeFunctions(link: link)
    
    func startCapture() throws {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = self.device
        captureDescriptor.destination = MTLCaptureDestination.developerTools
        try captureManager.startCapture(with: captureDescriptor)
    }
    

    func stopCapture() {
        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
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
}

// MARK: - Da Buffers

public extension MetalLinkReader {
    func createOffsetBuffer(index: UInt32) throws -> MTLBuffer {
        return try index.storedInMTLBuffer(link)
    }
}

public extension UInt32 {
    // Teeny buffer to write total character count
    func storedInMTLBuffer(_ link: MetalLink) throws -> MTLBuffer {
        let data = withUnsafeBytes(of: self) { Data($0) }
        guard let buffer = link.device.loadToMTLBuffer(data: data)
        else { throw ComputeError.bufferCreationFailed }
        return buffer
    }
}
