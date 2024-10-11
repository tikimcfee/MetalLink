//
//  MetalLinkAtlasBuilder.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import MetalKit
import Foundation
import BitHandling
import MetalLinkHeaders

public let GRAPHEME_BUFFER_DEFAULT_SIZE = 1_000_512

class HashCache: LockingCache<Character, UInt64> {
    override func make(_ key: Character, _ store: inout [Character : UInt64]) -> UInt64 {
        let prime: UInt64 = 31;
        return key.unicodeScalars.reduce(into: 0) { hash, scalar in
            hash = (hash * prime + UInt64(scalar.value)) % 1_000_000
        }
    }
}
let hashCache = HashCache()

public extension Character {
    var glyphComputeHash: UInt64 {
        hashCache[self]
    }
}

public class AtlasBuilder {
    private let link: MetalLink
    
    private let glyphBuilder = GlyphBuilder()
    internal let compute: ConvertCompute
    
    internal var atlasTexture: MTLTexture
    private lazy var atlasSize: LFloat2 = atlasTexture.simdSize
    
    private lazy var uvPacking = AtlasContainerUV(canvasWidth: 1.0, canvasHeight: 1.0)
    private lazy var vertexPacking = AtlasContainerVertex(canvasWidth: atlasTexture.width, canvasHeight: atlasTexture.height)
    
    public let cacheRef: TextureUVCache = TextureUVCache()
    private let sourceOrigin = MTLOrigin()
    private var targetOrigin = MTLOrigin()
    
    internal var currentGraphemeHashBuffer: MTLBuffer
    internal var unrenderableGlyphState: UnrenderableGlyph = .notSet
    
    public init(
        _ link: MetalLink,
        compute: ConvertCompute
    ) throws {
        guard let atlasTexture = link.device.makeTexture(descriptor: Self.canvasDescriptor)
        else { throw LinkAtlasError.noTargetAtlasTexture }
        atlasTexture.label = "MetalLinkAtlas - Init"
        
        self.compute = compute
        self.currentGraphemeHashBuffer = try compute.makeGraphemeAtlasBuffer(size: GRAPHEME_BUFFER_DEFAULT_SIZE)
        self.link = link
        self.atlasTexture = atlasTexture
    }
    
    public func save() {
        serialize()
    }
    
    public func load() {
        deserialize()
    }
    
    public func clear() {
        clearSerialization()
    }
}

public extension AtlasBuilder {
    enum UnrenderableGlyph: Codable {
        case notSet
        case set(TextureUVCache.Pair)
    }
    
    struct Serialization: Codable {
        let uvState: AtlasContainerUV
        let vertexState: AtlasContainerVertex
        let dimensions: LFloat2
        
        let pairCache: TextureUVCache
        let unrenderableGlyphState: UnrenderableGlyph
        
        let graphemeHashData: Data
        let graphemeHashCount: Int
    }
    
    private func clearSerialization() {
        AppFiles.delete(fileUrl: AppFiles.atlasSerializationURL)
        AppFiles.delete(fileUrl: AppFiles.atlasTextureURL)
    }
    
    private func deserialize() {
        let decoder = JSONDecoder()
        do {
            let serializationData = try Data(contentsOf: AppFiles.atlasSerializationURL)
            guard serializationData.count > 0 else {
                print("< -- no saved data! -- >")
                return
            }
            
            let serialization = try decoder.decode(Serialization.self, from: serializationData)
                        
            let atlasData = try Data(contentsOf: AppFiles.atlasTextureURL)
            let serializer = TextureSerializer(device: link.device)
            guard let atlasTexture = serializer.deserialize(
                data: atlasData,
                width: atlasTexture.width,
                height: atlasTexture.height
            ) else {
                throw LinkAtlasError.noTargetAtlasTexture
            }
            atlasTexture.label = "Deserialized Atlas Texture"
            
            let graphemeData = serialization.graphemeHashData
            guard let graphemeBuffer = link.device.loadToMTLBuffer(data: graphemeData) else {
                throw LinkAtlasError.deserializationErrorBuffer
            }
            graphemeBuffer.label = "Deserialized Grapheme Buffer"

            try reloadFrom(
                serialization: serialization,
                texture: atlasTexture,
                buffer: graphemeBuffer
            )
        }  catch {
            print(error)
        }
    }
    
    private func serialize() {
        let encoder = JSONEncoder()
        do {
            let graphemePointer = currentGraphemeHashBuffer.boundPointer(
                as: GlyphMapKernelAtlasIn.self, count: GRAPHEME_BUFFER_DEFAULT_SIZE
            )
            let unsafeBuffer = UnsafeBufferPointer(start: graphemePointer, count: GRAPHEME_BUFFER_DEFAULT_SIZE)
            let serializedGraphemeData: Data = Data(buffer: unsafeBuffer)
                
            let serialization = Serialization(
                uvState: uvPacking,
                vertexState: vertexPacking,
                dimensions: atlasSize,
                pairCache: cacheRef,
                unrenderableGlyphState: unrenderableGlyphState,
                graphemeHashData: serializedGraphemeData,
                graphemeHashCount: GRAPHEME_BUFFER_DEFAULT_SIZE
            )
            
            let serializationData = try encoder.encode(serialization)
            try serializationData.write(to: AppFiles.atlasSerializationURL)
            
            let textureSerializer = TextureSerializer(device: link.device)
            let textureData = textureSerializer.serialize(texture: atlasTexture)
            try textureData!.write(to: AppFiles.atlasTextureURL)
            
            print("Atlas was saved, I think.")
        } catch {
            print(error, "::: Atlas was not saved, probably.")
        }
    }
    
    private func reloadFrom(
        serialization: Serialization,
        texture: MTLTexture,
        buffer: MTLBuffer
    ) throws {
        self.uvPacking.currentX = serialization.uvState.currentX
        self.uvPacking.currentY = serialization.uvState.currentY
        self.uvPacking.largestHeightThisRow = serialization.uvState.largestHeightThisRow
        
        self.vertexPacking.currentX = serialization.vertexState.currentX
        self.vertexPacking.currentY = serialization.vertexState.currentY
        self.vertexPacking.largestHeightThisRow = serialization.vertexState.largestHeightThisRow
        
        self.cacheRef.map = serialization.pairCache.map
        self.cacheRef.unicodeMap = serialization.pairCache.unicodeMap
        
        self.atlasSize = serialization.dimensions
        
        self.atlasTexture = texture
        self.currentGraphemeHashBuffer = buffer
        self.unrenderableGlyphState = serialization.unrenderableGlyphState
    }
}


public extension AtlasBuilder {
    struct BuildBlock {
        let commandBuffer: MTLCommandBuffer
        let blitEncoder: MTLBlitCommandEncoder
        let atlasTexture: MTLTexture
        
        static func start(
            with link: MetalLink,
            targeting atlasTexture: MTLTexture
        ) throws -> BuildBlock {
            guard let commandQueue = link.device.makeCommandQueue(),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let blitEncoder = commandBuffer.makeBlitCommandEncoder()
            else { throw LinkAtlasError.noStateBuilder }
            
            let id = Self.NEXT_ID()
            commandBuffer.label = "AtlasBuilderCommands-\(id)"
            blitEncoder.label = "AtlasBuilderBlitter-\(id)"
            
            return BuildBlock(
                commandBuffer: commandBuffer,
                blitEncoder: blitEncoder,
                atlasTexture: atlasTexture
            )
        }
        
        private static var _MY_ID = 0
        private static func NEXT_ID() -> Int {
            let id = _MY_ID
            _MY_ID += 1
            return id
        }
    }
}
    
public extension AtlasBuilder {    
    func startAtlasUpdate() throws -> BuildBlock {
        try BuildBlock.start(
            with: link,
            targeting: atlasTexture
        )
    }
    
    func finishAtlasUpdate(from block: BuildBlock) {
        block.blitEncoder.endEncoding()
        block.commandBuffer.commit()
    }
    
    func addGlyph(
        _ key: GlyphCacheKey,
        _ block: BuildBlock
    ) {
        guard let bitmaps = glyphBuilder.makeBitmaps(key) else {
            print("Missing bitmaps for \(key)")
            return
        }
        
        // The bad glyph is data from a tiff block, at this size. Just.. I know, ok?
        #if os(macOS)
        let isUnrenderable = bitmaps.requested.tiffRepresentation == __UNRENDERABLE__GLYPH__DATA__
        #elseif os(iOS)
        let isUnrenderable = bitmaps.requested.pngData() == __UNRENDERABLE__GLYPH__DATA__
        #endif
        
        switch (isUnrenderable, unrenderableGlyphState) {
        case (true, .set(let glyph)):
            // Found an image we can't render with monospace font. Don't encode it.
            // Just reuse the unrenderableGlyph.
            cacheRef[key] = glyph
            return
            
        default:
            break
        }

        guard let texture = try? link.textureLoader.newTexture(
            cgImage: bitmaps.requestedCG,
            options: [.textureStorageMode: MTLStorageMode.private.rawValue]
        ) else {
            print("Missing texture for \(key)")
            return
        }
        
        print("Adding glyph to Atlas: [\(key)]")
        
        // Set Vertex and UV info for packing
        let bundleUVSize = atlasUVSize(for: texture)
        let uvRect = UVRect()
        uvRect.width = bundleUVSize.x
        uvRect.height = bundleUVSize.y
        
        let vertexRect = VertexRect()
        vertexRect.width = texture.width
        vertexRect.height = texture.height
        
        // Pack it; Update origin from rect position
        uvPacking.packNextRect(uvRect)
        vertexPacking.packNextRect(vertexRect)
        targetOrigin.x = vertexRect.x
        targetOrigin.y = vertexRect.y
        
        // Ship it; Encode with current state
        encodeBlit(for: texture, with: block)
        
        // Compute UV corners for glyph
        let (left, top, width, height) = (
            uvRect.x, uvRect.y,
            bundleUVSize.x, bundleUVSize.y
        )

        // Create UV pair matching glyph's texture position
        let topLeft = LFloat2(left, top)
        let bottomLeft = LFloat2(left, top + height)
        let topRight = LFloat2(left + width, top)
        let bottomRight = LFloat2(left + width, top + height)
        
        // You will see this a lot:
        // (x = left, y = top, z = width, w = height)
        let newPair = TextureUVCache.Pair(
            u: LFloat4(topRight.x, topLeft.x, bottomLeft.x, bottomRight.x),
            v: LFloat4(topRight.y, topLeft.y, bottomLeft.y, bottomRight.y),
            size: texture.simdSize
        )
        cacheRef[key] = newPair
        
        let hash = key.glyphComputeHash
        let hashIndex = Int(hash)
        let graphemePointer = currentGraphemeHashBuffer.boundPointer(
            as: GlyphMapKernelAtlasIn.self,
            count: GRAPHEME_BUFFER_DEFAULT_SIZE
        )
        graphemePointer[hashIndex].unicodeHash = hash
        graphemePointer[hashIndex].textureDescriptorU = newPair.u
        graphemePointer[hashIndex].textureDescriptorV = newPair.v
        graphemePointer[hashIndex].textureSize = newPair.size
        
        switch (isUnrenderable, unrenderableGlyphState) {
        case (true, .notSet):
            self.unrenderableGlyphState = .set(newPair)
            print("<!> Set unrenderable glyph location!")
        default:
            break
        }
    }
    
    func encodeBlit(
        for texture: MTLTexture,
        with block: BuildBlock
    ) {
        let textureSize = MTLSize(width: texture.width, height: texture.height, depth: 1)
        
        block.blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: sourceOrigin,
            sourceSize: textureSize,
            to: atlasTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: targetOrigin
        )
    }
}

private extension AtlasBuilder {
    func atlasUVSize(for bundle: TextureBundle) -> LFloat2 {
        let bundleSize = bundle.texture.simdSize
        return LFloat2(bundleSize.x / atlasSize.x, bundleSize.y / atlasSize.y)
    }
    
    func atlasUVSize(for texture: MTLTexture) -> LFloat2 {
        let bundleSize = texture.simdSize
        return LFloat2(bundleSize.x / atlasSize.x, bundleSize.y / atlasSize.y)
    }
}


#if os(macOS)
public let ATLAS_PIXEL_FORMAT = MTLPixelFormat.rgba8Unorm
#else
public let ATLAS_PIXEL_FORMAT = MTLPixelFormat.bgra8Unorm_srgb
#endif

public extension AtlasBuilder {
    
    // atlas texture size canvas buffer space length
    static var canvasSize = LInt2(1024 * 3, 1024 * 3)
    static var canvasDescriptor: MTLTextureDescriptor = {
        let glyphDescriptor = MTLTextureDescriptor()
        glyphDescriptor.storageMode = .private
        glyphDescriptor.textureType = .type2D
        
        glyphDescriptor.pixelFormat = ATLAS_PIXEL_FORMAT
        glyphDescriptor.width = canvasSize.x
        glyphDescriptor.height = canvasSize.y
        
        glyphDescriptor.allowGPUOptimizedContents = false

        return glyphDescriptor
    }()
}

public extension MTLDevice {
    func loadToMTLBuffer(data: Data) -> MTLBuffer? {
        return data.withUnsafeBytes { bufferPointer -> MTLBuffer? in
            guard let baseAddress = bufferPointer.baseAddress else { return nil }
            return makeBuffer(bytes: baseAddress, length: data.count, options: [])
        }
    }

}

