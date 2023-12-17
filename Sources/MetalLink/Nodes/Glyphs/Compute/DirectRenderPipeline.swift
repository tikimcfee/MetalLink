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
    public let collectionStream: CollectionStream
    
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
        self.collectionStream = dataStream
            .receive(on: DispatchQueue.global())
            .compactMap { data in
                do {
                    return try Self.regenerateCollection(
                        name: name,
                        for: data,
                        compute: compute,
                        atlas: atlas,
                        link: link
                    )
                } catch {
                    print(error)
                    return nil
                }
            }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }

    private static func regenerateCollection(
        name: String,
        for data: Data,
        compute: ConvertCompute,
        atlas: MetalLinkAtlas,
        link: MetalLink
    ) throws -> GlyphCollection {
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
    }
}
