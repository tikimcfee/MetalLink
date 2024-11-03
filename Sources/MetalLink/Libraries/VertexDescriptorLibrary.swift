//
//  DescriptorLibrary.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/7/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit
import BitHandling

public enum MetalLinkVertexType {
    private static let basic = BasicVertexDescriptor()
    private static let instanced = InstancedVertexDescriptor()
    
    case Basic
    case Instanced
    
    var descriptor: MTLVertexDescriptor {
        switch self {
        case .Basic:     return Self.basic.descriptor
        case .Instanced: return Self.instanced.descriptor
        }
    }
}

// MARK: Incremental build pattern
protocol MetalLinkVertexDescriptor {
    var name: String { get }
    var descriptor: MTLVertexDescriptor { get }
    
    var attributeIndex: Int { get }
    var bufferIndex: Int { get }
    var layoutIndex: Int { get }
}

// MARK: Basics
private struct BasicVertexDescriptor: MetalLinkVertexDescriptor {
    var name = "Basic Vertex Component"
    let descriptor = MTLVertexDescriptor()
    var attributeIndex: Int = 0
    var attributeOffset: Int = 0
    var bufferIndex: Int = 0
    var layoutIndex: Int = 0
    
    init() {
        // Vertex Position
        descriptor.attributes[attributeIndex].format = .float3
        descriptor.attributes[attributeIndex].bufferIndex = bufferIndex
        descriptor.attributes[attributeIndex].offset = 0
        attributeIndex += 1
        attributeOffset += LFloat3.memSize
        
        // UV Texture Index
        descriptor.attributes[attributeIndex].format = .uint
        descriptor.attributes[attributeIndex].bufferIndex = bufferIndex
        descriptor.attributes[attributeIndex].offset = attributeOffset
        attributeIndex += 1
        attributeOffset += UInt.memSize

        // Layout
        descriptor.layouts[layoutIndex].stride = Vertex.memStride
        descriptor.layouts[layoutIndex].stepFunction = .perVertex
        descriptor.layouts[layoutIndex].stepRate = 1
    }
}

// MARK: Instanced
private struct InstancedVertexDescriptor: MetalLinkVertexDescriptor {
    var name = "Instanced Vertex Component"
    let descriptor = MTLVertexDescriptor()
    var attributeIndex: Int = 0
    var attributeOffset: Int = 0
    var bufferIndex: Int = 0
    var layoutIndex: Int = 0
    
    init() {
        // Vertex Position
        descriptor.attributes[attributeIndex].format = .float3
        descriptor.attributes[attributeIndex].bufferIndex = bufferIndex
        descriptor.attributes[attributeIndex].offset = 0
        attributeIndex += 1
        attributeOffset += LFloat3.memSize
        
        // UV Texture Index
        descriptor.attributes[attributeIndex].format = .uint
        descriptor.attributes[attributeIndex].bufferIndex = bufferIndex
        descriptor.attributes[attributeIndex].offset = attributeOffset
        attributeIndex += 1
        attributeOffset += UInt.memSize
        
        // Layout
        descriptor.layouts[layoutIndex].stride = Vertex.memStride
        descriptor.layouts[layoutIndex].stepFunction = .perVertex
        descriptor.layouts[layoutIndex].stepRate = 1
    }
}
