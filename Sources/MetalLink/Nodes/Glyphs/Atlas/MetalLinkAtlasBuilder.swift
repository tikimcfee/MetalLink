//
//  MetalLinkAtlasBuilder.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/13/22.
//

import MetalKit
import BitHandling

public struct TextureUVCache: Codable {
    public struct Pair: Codable {
        public let u: LFloat4
        public let v: LFloat4
        
        public init(u: LFloat4, v: LFloat4) {
            self.u = u
            self.v = v
        }
    }

//    public var map = ConcurrentDictionary<GlyphCacheKey, Pair>()
    public var map = [GlyphCacheKey: Pair]()
    
    public init() {
        
    }
    
    public subscript(_ key: GlyphCacheKey) -> Pair? {
        get { map[key] }
        set { map[key] = newValue }
    }
}

public class AtlasBuilder {
    private let link: MetalLink
    private let textureCache: MetalLinkGlyphTextureCache
    
    var atlasTexture: MTLTexture
    private lazy var atlasSize: LFloat2 = atlasTexture.simdSize
    
    private lazy var uvPacking = AtlasPacking<UVRect>(width: 1.0, height: 1.0)
    private lazy var vertexPacking = AtlasPacking<VertexRect>(width: atlasTexture.width, height: atlasTexture.height)
    
    private var uvPairCache: TextureUVCache = TextureUVCache()
    
    private let sourceOrigin = MTLOrigin()
    private var targetOrigin = MTLOrigin()
    
    public init(
        _ link: MetalLink,
        textureCache: MetalLinkGlyphTextureCache
    ) throws {
        guard let atlasTexture = link.device.makeTexture(descriptor: Self.canvasDescriptor)
        else { throw LinkAtlasError.noTargetAtlasTexture }
        
        self.link = link
        self.textureCache = textureCache
        self.atlasTexture = atlasTexture
        
        atlasTexture.label = "MetalLinkAtlas"
    }
    
    func load() {
        
    }
    
    func serialize() {
        fatalError("it's commented out man")
//        let encoder = JSONEncoder()
//        do {
//            let uv = try encoder.encode(uvPacking.save())
//            let vertex = try encoder.encode(vertexPacking.save())
//            let pairCache = try encoder.encode(uvPairCache)
//            let dimensions = try encoder.encode(atlasSize)
//            
//            let serializer = TextureSerializer(device: link.device)
//            let textureData = serializer.serialize(texture: atlasTexture)!
//            
//            let reloadedTexture = serializer.deserialize(
//                data: textureData,
//                width: atlasTexture.width,
//                height: atlasTexture.height
//            )!
//            
//            let allIsRightWithWorld = [
//                atlasTexture.pixelFormat == reloadedTexture.pixelFormat,
//                atlasTexture.arrayLength == reloadedTexture.arrayLength,
//                atlasTexture.sampleCount == reloadedTexture.sampleCount
//            ].allSatisfy { $0 }
//            
//            atlasTexture = reloadedTexture
//            if !allIsRightWithWorld {
//                print("All is not right with the world.")
//            } else {
//                print("All is right with the world.")
//            }
//            print("Done")
//        } catch {
//            print(error)
//        }
    }
    
//    func serializeMTLTexture(texture: MTLTexture) -> NSData? {
//        let dataSize = texture.width * texture.height * 4
//        guard let textureData = malloc(dataSize) else { return nil }
//        
//        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
//        texture.getBytes(textureData, bytesPerRow: texture.width * 4, from: region, mipmapLevel: 0)
//
//        return NSData(bytesNoCopy: textureData, length: dataSize, freeWhenDone: true)
//    }
//    
//    func deserializeMTLTexture(textureData: Data) {
//        guard let atlasTexture = link.device.makeTexture(descriptor: Self.canvasDescriptor) else {
//            return
//        }
//        
//        
//        textureData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
//            let region = MTLRegionMake2D(0, 0, atlasTexture.width, atlasTexture.height)
//            atlasTexture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: atlasTexture.width * 4)
//        }
//    }
}


class TextureSerializer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
    }
    
    func serialize(texture: MTLTexture) -> Data? {
        let stagingTexture = createStagingTexture(from: texture, device: device)
        copyTextureToStagingTexture(texture: texture, stagingTexture: stagingTexture, commandBuffer: commandQueue.makeCommandBuffer()!)
        return textureToData(texture: stagingTexture)
    }
    
    func deserialize(data: Data, width: Int, height: Int) -> MTLTexture? {
        return dataToTexture(data: data, device: device, width: width, height: height)
    }
    
    private func createStagingTexture(from texture: MTLTexture, device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = texture.textureType
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.storageMode = .shared
        return device.makeTexture(descriptor: descriptor)!
    }
    
    private func copyTextureToStagingTexture(texture: MTLTexture, stagingTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let encoder = commandBuffer.makeBlitCommandEncoder()!
        encoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, 
                     sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                     sourceSize: MTLSize(width: texture.width, height: texture.height, depth: texture.depth),
                     to: stagingTexture, destinationSlice: 0, destinationLevel: 0,
                     destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func textureToData(texture: MTLTexture) -> Data {
        let rowBytes = texture.width * 4 // Assuming BGRA8Unorm format
        let length = rowBytes * texture.height
        let pointer = malloc(length)
        texture.getBytes(pointer!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return Data(bytesNoCopy: pointer!, count: length, deallocator: .free)
    }
    
    private func dataToTexture(data: Data, device: MTLDevice, width: Int, height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = width
        descriptor.height = height
        descriptor.storageMode = .shared
        let texture = device.makeTexture(descriptor: descriptor)!
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
            texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
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
            guard let commandBuffer = link.commandQueue.makeCommandBuffer(),
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
    typealias UpdatedAtlas = (
        atlas: MTLTexture,
        uvCache: TextureUVCache
    )
    
    func startAtlasUpdate() throws -> BuildBlock {
        try BuildBlock.start(with: link, targeting: atlasTexture)
    }
    
    func finishAtlasUpdate(from block: BuildBlock) -> UpdatedAtlas {
        block.blitEncoder.endEncoding()
        block.commandBuffer.commit()
        return (atlasTexture, uvPairCache)
    }
    
    func addGlyph(
        _ key: GlyphCacheKey,
        _ block: BuildBlock
    ) {
        guard let textureBundle = textureCache[key] else {
            print("Missing texture for \(key)")
            return
        }
        
        // Set Vertex and UV info for packing
        let bundleUVSize = atlasUVSize(for: textureBundle)
        let uvRect = UVRect()
        uvRect.width = bundleUVSize.x
        uvRect.height = bundleUVSize.y
        
        let vertexRect = VertexRect()
        vertexRect.width = textureBundle.texture.width
        vertexRect.height = textureBundle.texture.height
        
        // Pack it; Update origin from rect position
        uvPacking.packNextRect(uvRect)
        vertexPacking.packNextRect(vertexRect)
        targetOrigin.x = vertexRect.x
        targetOrigin.y = vertexRect.y
        
        // Ship it; Encode with current state
        encodeBlit(for: textureBundle.texture, with: block)
        
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
        uvPairCache[key] = TextureUVCache.Pair(
            u: LFloat4(topRight.x, topLeft.x, bottomLeft.x, bottomRight.x),
            v: LFloat4(topRight.y, topLeft.y, bottomLeft.y, bottomRight.y)
        )
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
    func atlasUVSize(for bundle: MetalLinkGlyphTextureCache.Bundle) -> LFloat2 {
        let bundleSize = bundle.texture.simdSize
        return LFloat2(bundleSize.x / atlasSize.x, bundleSize.y / atlasSize.y)
    }
}

public extension AtlasBuilder {
    // atlas texture size canvas buffer space length
    static var canvasSize = LInt2(4096 * 2, 4096 * 2)
    static var canvasDescriptor: MTLTextureDescriptor = {
        let glyphDescriptor = MTLTextureDescriptor()
        glyphDescriptor.storageMode = .private
        glyphDescriptor.textureType = .type2D
        glyphDescriptor.pixelFormat = .rgba8Unorm
        
        // TODO: Optimized behavior clears 'empty' backgrounds
        // We don't want this: spaces count, and they're colored.
        // Not sure what we lose with this.. but we'll see.
        glyphDescriptor.allowGPUOptimizedContents = false
        
        glyphDescriptor.width = canvasSize.x
        glyphDescriptor.height = canvasSize.y
        return glyphDescriptor
    }()
}

