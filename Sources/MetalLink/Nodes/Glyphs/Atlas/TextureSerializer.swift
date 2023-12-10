//  
//
//  Created on 11/27/23.
//  

import Foundation
import Metal

class TextureSerializer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
    }
    
    func serialize(texture: MTLTexture) -> Data? {
        let stagingTexture = createStagingTexture(device: device)
        copyTextureToStagingTexture(texture: texture, stagingTexture: stagingTexture, commandBuffer: commandQueue.makeCommandBuffer()!)
        return textureToData(texture: stagingTexture)
    }
    
    func deserialize(data: Data, width: Int, height: Int) -> MTLTexture? {
        return dataToTexture(data: data, device: device, width: width, height: height)
    }
    
    private func createStagingTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = AtlasBuilder.canvasDescriptor
        descriptor.storageMode = .shared // We're writing to the text manually, need to update mode
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
        let rowBytes = texture.width * 4 // assumes ATLAS_PIXEL_FORMAT size is always * 4
        let length = rowBytes * texture.height
        let pointer = malloc(length)
        texture.getBytes(pointer!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return Data(bytesNoCopy: pointer!, count: length, deallocator: .free)
    }
    
    private func dataToTexture(data: Data, device: MTLDevice, width: Int, height: Int) -> MTLTexture {
        let descriptor = AtlasBuilder.canvasDescriptor
        descriptor.storageMode = .shared // We're writing to the text manually, need to update mode
        
        let texture = device.makeTexture(descriptor: descriptor)!
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
            texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }
}
