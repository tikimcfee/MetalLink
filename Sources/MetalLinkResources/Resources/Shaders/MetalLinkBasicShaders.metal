//
//  MetalLinkBasicShaders.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/10/22.
//

#include <metal_stdlib>
//using namespace metal;

//#include "include/MetalLinkResources.h"
#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

float4x4 scaleBy_Basic(float3 s) {
    return float4x4(float4(s.x,  0,   0, 0),
                    float4(0,  s.y,   0, 0),
                    float4(0,    0, s.z, 0),
                    float4(0,    0,   0, 1));
}

float4x4 translationOf_Basic(float3 offset) {
    return float4x4(float4( 1, 0, 0, 0),
                    float4( 0, 1, 0, 0),
                    float4( 0, 0, 1, 0),
                    float4(offset.x, offset.y, offset.z, 1));
}


bool getNthBit_Basic(int8_t value, uint8_t bitPosition) {
    // Check if the bit at the given position is set (1) or not (0)
    return (value & (1 << bitPosition)) != 0;
}

// recall buffer(x) is the Swift-defined buffer position for these vertices
vertex RasterizerData basic_vertex_function(
    const VertexIn vertexIn [[ stage_in ]],
    constant SceneConstants &sceneConstants [[ buffer(1) ]],
    constant BasicModelConstants &modelConstants [[ buffer(4) ]]
) {
    RasterizerData rasterizerData;
    float4x4 modelMatrix = modelConstants.modelMatrix;
    
//    bool isSearchMatched = getNthBit_Basic(modelConstants.flags, 2);
//    if (isSearchMatched) {
//        const float scale = 5;
//        
//        const float scaledWidth = modelConstants.width * scale;
//        const float scaledHeight = modelConstants.height * scale;
//        const float widthDelta = scaledWidth - modelConstants.width;
//        const float heightDelta = scaledHeight - modelConstants.height;
//        modelMatrix = modelMatrix * scaleBy_Basic(float3(
//            scale,
//            scale,
//            1.0
//        ));
////        modelMatrix = modelMatrix * translationOf_Basic(float3(
////            scaledWidth,
////            scaledHeight,
////            50.0
////        ));
//    }
    
    rasterizerData.position =
    sceneConstants.projectionMatrix // camera
    * sceneConstants.viewMatrix     // viewport
    * modelMatrix                   // transforms
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
