//
//  SafeDrawPass.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/6/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit
import MetalLinkHeaders

public class SafeDrawPass {
    private static var reusedPassContainer: SafeDrawPass?
    
    public var renderPassDescriptor: MTLRenderPassDescriptor
    public var renderCommandEncoder: MTLRenderCommandEncoder
    public var commandBuffer: MTLCommandBuffer
    
    private var currents = Currents()

        
    private init(
        renderPassDescriptor: MTLRenderPassDescriptor,
        renderCommandEncoder: MTLRenderCommandEncoder,
        commandBuffer: MTLCommandBuffer
    ) {
        self.renderPassDescriptor = renderPassDescriptor
        self.renderCommandEncoder = renderCommandEncoder
        self.commandBuffer = commandBuffer
    }
    
    func reset() {
        currents = Currents()
    }
    
    public func oncePerPass(_ key: String, _ action: (SafeDrawPass) -> Void) {
        guard currents.renderFlags[key] == nil else { return }
        action(self)
        currents.renderFlags[key] = "did-execute-once-\(key)"
    }
}

extension SafeDrawPass {
    struct Currents {
        var pipeline: MTLRenderPipelineState?
        var depthStencil: MTLDepthStencilState?
        var renderFlags = [String: Any]()
        
        var material: MetalLinkMaterial?
        
        // [Length: [Index: Buffer]]
        var vertexBuffer = [Int: [Int: MTLBuffer]]()
        
        // [Offset: [Index: Buffer]]
        var vertexBytes = [Int: [Int: any Equatable]]()
    }
    
    public var currentPipeline: MTLRenderPipelineState? {
        get { currents.pipeline }
        set {
            guard currents.pipeline?.label != newValue?.label else {
                return
            }
            currents.pipeline = newValue
            if let newValue {
                renderCommandEncoder.setRenderPipelineState(newValue)
            }
        }
    }
    
    public var currentDepthStencil: MTLDepthStencilState? {
        get { currents.depthStencil }
        set {
            guard currents.depthStencil?.label != newValue?.label else {
                return
            }
            currents.depthStencil = newValue
            if let newValue {
                renderCommandEncoder.setDepthStencilState(newValue)
            }
        }
    }
    
    public var currentBasicMaterial: MetalLinkMaterial? {
        get { currents.material }
        set {
            guard currents.material != newValue else {
                return
            }
            currents.material = newValue
            if var safeValue = newValue {
                renderCommandEncoder.setFragmentBytes(
                    &safeValue,
                    length: MetalLinkMaterial.memStride,
                    index: 1
                )
                
            }
        }
    }
    
    public func setCurrentVertexBuffer<T: MTLBuffer>(
        _ buffer: T,
        _ offset: Int,
        _ index: Int
    ) {
        let current = currents.vertexBuffer[offset]?[index]
        guard
            (current as? T)?.contents() != buffer.contents() else
        {
            return
        }
        currents.vertexBuffer[offset, default: [:]][index] = buffer
        renderCommandEncoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
    
    public func setCurrentVertexBytes<T: Equatable>(
        _ bytes: inout T,
        _ length: Int,
        _ index: Int
    ) {
        let current = currents.vertexBytes[length]?[index]
        guard
            (current as? T) != bytes
        else {
            return
        }
        currents.vertexBytes[length, default: [:]][index] = bytes
        renderCommandEncoder.setVertexBytes(&bytes, length: length, index: index)
    }
}



extension SafeDrawPass {
    static func wrap(_ link: MetalLink) -> SafeDrawPass? {
        guard let renderPassDescriptor = link.view.currentRenderPassDescriptor
        else {
            return nil
        }
        
        // TODO:
        // setup a start/stop for descriptor updates.
        // look at other implementations of engines.
        // or... use one... ...  .
        link.glyphPickingTexture.updateDescriptor(renderPassDescriptor)
        link.gridPickingTexture.updateDescriptor(renderPassDescriptor)
        
        guard let commandBuffer = link.commandQueue.makeCommandBuffer(),
              let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return nil
        }
        
        if let container = reusedPassContainer {
            container.renderPassDescriptor = renderPassDescriptor
            container.renderCommandEncoder = renderCommandEncoder
            container.commandBuffer = commandBuffer
            container.reset()
            return container
        } else {
            let container = SafeDrawPass(
                renderPassDescriptor: renderPassDescriptor,
                renderCommandEncoder: renderCommandEncoder,
                commandBuffer: commandBuffer
            )
            reusedPassContainer = container
            return container
        }
    }
}
