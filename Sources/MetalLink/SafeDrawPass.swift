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
        currents.reset()
    }
    
    public func oncePerPass(_ key: String, _ action: (SafeDrawPass) -> Void) {
        guard !currents.oneTimeFlags.contains(key) else { return }
        action(self)
        currents.oneTimeFlags.insert(key)
    }
}

extension SafeDrawPass {
    class Currents {
        var pipeline: MTLRenderPipelineState?
        var depthStencil: MTLDepthStencilState?
        var material: MetalLinkMaterial?
        
        var oneTimeFlags = Set<String>()
        
        func reset() {
            pipeline = nil
            depthStencil = nil
            material = nil
            
            oneTimeFlags.removeAll(keepingCapacity: true)
        }
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
    
    public func setCurrentVertexBuffer(
        _ buffer: MTLBuffer,
        _ offset: Int,
        _ index: Int
    ) {
        renderCommandEncoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
    
    public func setCurrentVertexBytes(
        _ bytes: UnsafeRawPointer,
        _ length: Int,
        _ index: Int
    ) {
        renderCommandEncoder.setVertexBytes(bytes, length: length, index: index)
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
        
        guard let commandBuffer = link.defaultCommandQueue.makeCommandBuffer(),
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
