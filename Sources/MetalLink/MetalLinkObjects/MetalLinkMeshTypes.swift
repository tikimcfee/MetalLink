//
//  MetalLinkTriangleMesh.swift
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/7/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

import MetalKit

public enum UVIndex: TextureIndex {
    case topRight = 0
    case topLeft = 1
    case bottomLeft = 2
    case bottomRight = 3
    
    case topMiddle = 4
    case bottomMiddle = 5
    case leftMiddle = 6
    case rightMiddle = 7
    
    case noPositionFlat = 8
}

private func vertex(
    _ x: Float,
    _ y: Float,
    _ z: Float,
    _ uvIndex: UVIndex
) -> Vertex {
    Vertex(
        position: LFloat3(x, y, z),
        uvTextureIndex: uvIndex.rawValue
    )
}

public class MetalLinkTriangleMesh: MetalLinkBaseMesh {
    public override var name: String { "MetalLinkTriangle>" }
    public override func createVertices() -> [Vertex] { [
        vertex( 0, 1, 0, .topMiddle),
        vertex(-1,-1, 0, .bottomLeft),
        vertex( 1,-1, 0, .bottomRight)
    ] }
}

public class MetalLinkQuadMesh: MetalLinkBaseMesh {
    public override var name: String { "MetalLinkQuad" }
    public var initialSizeSet: Bool = false
    
    // Texture coordinate order:
    override func createVertices() -> [Vertex] { [
        vertex( 1, 1, 0, .topRight),    /* T R 0 */
        vertex(-1, 1, 0, .topLeft),     /* T L 1 */
        vertex(-1,-1, 0, .bottomLeft),  /* B L 2 */
        vertex( 1, 1, 0, .topRight),    /* T R 3 */
        vertex(-1,-1, 0, .bottomLeft),  /* B L 4 */
        vertex( 1,-1, 0, .bottomRight)  /* B R 5 */
    ] }
}

public extension MetalLinkQuadMesh {
    static let TopRight = (0, 3)
    static let TopLeft = 1
    static let BotLeft = (2, 4)
    static let BotRight = 5
    
    var topLeftPos: LFloat3 {
        get {
            vertices[Self.TopLeft].position
        }
        set {
            vertices[Self.TopLeft].position = newValue
        }
    }
    
    var topRightPos: LFloat3 {
        get {
            vertices[Self.TopRight.0].position
        }
        set {
            vertices[Self.TopRight.0].position = newValue
            vertices[Self.TopRight.1].position = newValue
        }
    }
    
    var botLeftPos: LFloat3 {
        get {
            vertices[Self.BotLeft.0].position
        }
        set {
            vertices[Self.BotLeft.0].position = newValue
            vertices[Self.BotLeft.1].position = newValue
        }
    }
    
    var botRightPos: LFloat3 {
        get {
            vertices[Self.BotRight].position
        }
        set {
            vertices[Self.BotRight].position = newValue
        }
    }
    
    var topLeft: Vertex {
        get { vertices[1] }
        set { vertices[1] = newValue }
    }
    
    var topRight: Vertex {
        get { vertices[0] }
        set { vertices[0] = newValue; vertices[3] = newValue }
    }
    
    var bottomLeft: Vertex {
        get { vertices[2] }
        set { vertices[2] = newValue; vertices[4] = newValue }
    }
    
    var bottomRight: Vertex {
        get { vertices[5] }
        set { vertices[5] = newValue }
    }
    
    var halfWidth: Float { width / 2.0 }
    var width: Float {
        get { abs(vertices[0].position.x - vertices[1].position.x) }
    }
    
    var halfHeight: Float { height / 2.0 }
    var height: Float {
        get { abs(vertices[1].position.y - vertices[2].position.y) }
    }
    
    func setSize(_ size: LFloat2) {
        guard !initialSizeSet else { return }
        initialSizeSet = true

        setWidth(size.x)
        setHeight(size.y)
        
        func setWidth(_ width: Float) {
            let halfWidth = width / 2.0
            vertices[1].position.x = -halfWidth
            vertices[2].position.x = -halfWidth
            vertices[4].position.x = -halfWidth
            vertices[0].position.x = halfWidth
            vertices[3].position.x = halfWidth
            vertices[5].position.x = halfWidth
        }
        
        func setHeight(_ height: Float) {
            let halfHeight = height / 2.0
            vertices[0].position.y = halfHeight
            vertices[1].position.y = halfHeight
            vertices[3].position.y = halfHeight
            vertices[2].position.y = -halfHeight
            vertices[4].position.y = -halfHeight
            vertices[5].position.y = -halfHeight
        }
    }
}
