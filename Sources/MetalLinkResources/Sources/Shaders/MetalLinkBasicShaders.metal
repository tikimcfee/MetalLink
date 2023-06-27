//
//  MetalLinkBasicShaders.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/10/22.
//

#include <metal_stdlib>
//using namespace metal;

#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

// recall buffer(x) is the Swift-defined buffer position for these vertices
vertex RasterizerData basic_vertex_function(
    const VertexIn vertexIn [[ stage_in ]],
    constant SceneConstants &sceneConstants [[ buffer(1) ]],
    constant BasicModelConstants &modelConstants [[ buffer(4) ]]
) {
    RasterizerData rasterizerData;
    
    rasterizerData.position =
    sceneConstants.projectionMatrix // camera
    * sceneConstants.viewMatrix     // viewport
    * modelConstants.modelMatrix    // transforms
    * float4(vertexIn.position, 1)  // current position
    ;
    
    rasterizerData.totalGameTime = sceneConstants.totalGameTime;
    
    rasterizerData.modelInstanceID = modelConstants.pickingId;
    rasterizerData.textureCoordinate = float2(vertexIn.position.x, vertexIn.position.y);
    
    return rasterizerData;
}

fragment BasicPickingTextureFragmentOut basic_fragment_function(
   RasterizerData rasterizerData [[ stage_in ]],
   constant Material &material [[ buffer(1) ]]
) {
    float4 color = material.color;
    
    BasicPickingTextureFragmentOut out;
    out.mainColor = float4(color.r, color.g, color.b, color.a);
    out.pickingID = rasterizerData.modelInstanceID;
    
    return out;
}

kernel void calculate_forces(device ForceLayoutNode* nodes [[ buffer(0) ]],
                            device ForceLayoutEdge* edges [[ buffer(1) ]],
                            constant uint& edgeCount [[ buffer(2) ]],
                            uint id [[ thread_position_in_grid ]]) {
    // Get the current node
    ForceLayoutNode node = nodes[id];

    // Reset forces
    node.force = float3(0, 0, 0);

    // Calculate attractive forces
    for (uint i = 0; i < edgeCount; ++i) {
        ForceLayoutEdge edge = edges[i];
        if (edge.node1 == id || edge.node2 == id) {
            ForceLayoutNode otherNode = nodes[edge.node1 == id ? edge.node2 : edge.node1];
            float3 direction = otherNode.fposition - node.fposition;
            float distance = length(direction);
            if (distance > 0) {
                direction /= distance;  // Normalize direction
                float force = edge.strength * distance;
                node.force += force * direction;
            }
        }
    }

    // Update the node in the buffer
    nodes[id] = node;
}
