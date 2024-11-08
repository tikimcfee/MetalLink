//
//  MetalLinkMesh.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/7/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit
import BitHandling

public protocol MetalLinkMesh {
    func getVertexBuffer() -> MTLBuffer?
    func deallocateVertexBuffer()  // TODO: Don't deallocate the entire buffer.. at least pool it... clear it?
    var vertexCount: Int { get }
    var vertices: [Vertex] { get set }
    var name: String { get }
}

public class MetalLinkBaseMesh: MetalLinkMesh {
    private let link: MetalLink
    private var vertexBuffer: MTLBuffer?
    
    public var vertices: [Vertex] = []
    public var vertexCount: Int { vertices.count }
    
    public var name: String { "BaseMesh" }

    init(_ link: MetalLink) {
        self.link = link
        self.vertices = createVertices()
    }
    
    public func getVertexBuffer() -> MTLBuffer? {
        guard !vertices.isEmpty else { return nil }
        if let buffer = vertexBuffer { return buffer }
        vertexBuffer = try? Self.createVertexBuffer(with: link, for: vertices)
        vertexBuffer?.label = name
        return vertexBuffer
    }
    
    public func deallocateVertexBuffer() {
        vertexBuffer = nil
    }
    
    func createVertices() -> [Vertex] { [] }
}

private extension MetalLinkBaseMesh {
    static func createVertexBuffer(
        with link: MetalLink,
        for vertices: [Vertex]
    ) throws -> MTLBuffer {
        let memoryLength = vertices.count * Vertex.memStride
        
        guard !vertices.isEmpty, let buffer = link.device.makeBuffer(
            bytes: vertices, 
            length: memoryLength,
            options: []
        ) else {
            throw CoreError.noBufferAvailable
        }
        
        return buffer
    }
}

