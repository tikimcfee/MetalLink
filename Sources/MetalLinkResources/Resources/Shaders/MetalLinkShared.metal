//
//  MetalLinkShared.metal
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/10/22.
//

#ifndef MetalLinkShared_h
#define MetalLinkShared_h
#include <metal_stdlib>
//#include "include/MetalLinkResources.h"
using namespace metal;

// MARK: - GPU Constants

struct VertexIn {
    float3 position             [[ attribute(0) ]];
    uint uvTextureIndex         [[ attribute(1) ]];
};

struct RasterizerData {
    float totalGameTime;
    
    float4 position [[ position ]];
    float3 vertexPosition [[ flat ]];
    float2 textureCoordinate;
    
    uint modelInstanceID [[ flat ]];
    float4 addedColor;
    float4 multipliedColor;
};

struct Material {
    float4 color;
    bool useMaterialColor;
};

struct PickingTextureFragmentOut {
    float4 mainColor     [[ color(0) ]];
    uint pickingID       [[ color(1) ]];
};

struct BasicPickingTextureFragmentOut {
    float4 mainColor     [[ color(0) ]];
    uint pickingID       [[ color(2) ]];
};


struct ForceLayoutNode {
    // The position of the node in 3D space.
    // This is updated over time based on the node's velocity.
    float3 fposition;

    // The velocity of the node in 3D space.
    // This is updated over time based on the forces acting on the node.
    float3 velocity;

    // The force acting on the node in 3D space.
    // This is calculated each frame based on the node's relationships (edges)
    // and interactions with other nodes.
    float3 force;

    // The mass of the node.
    // In this context, it represents the number of connections (edges) the node has.
    // Nodes with more connections will have a larger mass and will therefore be
    // less affected by forces.
    float3 mass;
};

// Edge Struct
struct ForceLayoutEdge {
    // The first node in the relationship.
    // An edge always connects two nodes.
    uint node1;

    // The second node in the relationship.
    // An edge always connects two nodes.
    uint node2;

    // The strength of the relationship between node1 and node2.
    // This is used when calculating the attractive force between the two nodes.
    // Nodes with a stronger relationship will be pulled closer together.
    float strength;
};

#endif
