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
    public typealias InputBufferList = ConcurrentArray<(URL, MTLBuffer)>
    public typealias ErrorList = ConcurrentArray<Error>
    public typealias ResultList = ConcurrentArray<EncodeResult>
    
    public let link: MetalLink
    public init(link: MetalLink) { self.link = link }
    
    internal lazy var functions = ConvertComputeFunctions(link: link)
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
