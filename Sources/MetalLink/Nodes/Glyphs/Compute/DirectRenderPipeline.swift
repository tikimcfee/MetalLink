//  
//
//  Created on 12/14/23.
//  

import Foundation
import MetalKit
import MetalLinkHeaders
import BitHandling
import Combine

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
        let encodeResult = try compute.executeSingleWithAtlas(
            source: sourceUrl,
            atlas: atlas
        )
        
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

public class DataStreamRenderer: MetalLinkReader {
    public typealias DataStream = AnyPublisher<Data, Never>
    public typealias CollectionStream = AnyPublisher<GlyphCollection, Never>
    
    public let link: MetalLink
    public var atlas: MetalLinkAtlas
    public let compute: ConvertCompute
    public let name: String
    
    public let sourceStream: DataStream
    public lazy var collectionStream: CollectionStream = makeCollectionStream()
    public private(set) var lastEncodeResult: EncodeResult?
    
    private var token: Any?
    
    public init(
        link: MetalLink,
        atlas: MetalLinkAtlas,
        compute: ConvertCompute,
        dataStream: DataStream,
        name: String
    ) {
        self.link = link
        self.atlas = atlas
        self.compute = compute
        self.name = name
        self.sourceStream = dataStream
    }
}

extension DataStreamRenderer {
    private func makeCollectionStream() -> CollectionStream {
        sourceStream
            .receive(on: WorkerPool.shared.nextWorker())
            .compactMap(regenerateCollection(for:))
            .share()
            .eraseToAnyPublisher()
    }
    
    func startCapture() throws {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = self.device
        try captureManager.startCapture(with: captureDescriptor)
    }
    

    func stopCapture() {
        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
    }
    
    private func regenerateCollection(
        for data: Data
    ) -> GlyphCollection? {
        do {
            let encodeResult = try compute.executeDataWithAtlas(
                name: name,
                source: data,
                atlas: atlas
            )
            
            switch encodeResult.collection {
            case .built(let result):
                return result
                
            case .notBuilt:
                print("""
                XXX - Encoding pipeline failed for name: \(name)
                XXX   Returning default empty collection. Expect bad things.
                """)
                return try GlyphCollection(link: link, linkAtlas: atlas)
            }
        } catch {
            print(error)
            return nil
        }
    }
}
