//
//  SwiftGlyphInstancingShader.metal
//  MetalSimpleInstancing
//
//  Created by Ivan Lugo on 8/6/22.
//  Copyright © 2022 Metal by Example. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

//#include "include/MetalLinkResources.h"
#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

constant float4x4 identityMatrix = float4x4(1.0);

float4x4 scaleBy(float3 s) {
    return float4x4(float4(s.x,  0,   0, 0),
                    float4(0,  s.y,   0, 0),
                    float4(0,    0, s.z, 0),
                    float4(0,    0,   0, 1));
}

float4x4 translationOf_I(float3 offset) {
    return float4x4(float4( 1, 0, 0, 0),
                    float4( 0, 1, 0, 0),
                    float4( 0, 0, 1, 0),
                    float4(offset.x, offset.y, offset.z, 1));
}


float4x4 rotate(float3 axis, float angleRadians) {
    float x = axis.x, y = axis.y, z = axis.z;
    float c = cos(angleRadians);
    float s = sin(angleRadians);
    float t = 1 - c;
    return float4x4(float4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                    float4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                    float4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                    float4(                 0,                 0,                 0, 1));
}

float4x4 rotateAboutX(float angleRadians) {
    constexpr float3 X_AXIS = float3(1, 0, 0);
    return rotate(X_AXIS, angleRadians);
}

float4x4 rotateAboutY(float angleRadians) {
    constexpr float3 X_AXIS = float3(0, 1, 0);
    return rotate(X_AXIS, angleRadians);
}

float4x4 rotateAboutZ(float angleRadians) {
    constexpr float3 X_AXIS = float3(0, 0, 1);
    return rotate(X_AXIS, angleRadians);
}

float4 colorBlend_Add(float4 bottom, float4 top) {
    bottom.r = bottom.r + top.r;
    bottom.g = bottom.g + top.g;
    bottom.b = bottom.b + top.b;
    return bottom;
}

float4 colorBlend_Overlay(float4 bottom, float4 top) {
    if (bottom.r < 0.5) { bottom.r = bottom.r * top.r * 2; }
    else { bottom.r = 1 - 2 * ( 1 - bottom.r) * (1 - top.r); }
    
    if (bottom.g < 0.5) { bottom.g = bottom.g * top.g * 2; }
    else { bottom.g = 1 - 2 * ( 1 - bottom.g) * (1 - top.g); }
    
    if (bottom.b < 0.5) { bottom.b = bottom.b * top.b * 2; }
    else { bottom.b = 1 - 2 * ( 1 - bottom.b) * (1 - top.b); }
    
    return bottom;
}

float4 colorBlend_Screen(float4 a, float4 b) {
    return float4(1) - (float4(1) - a) * (float4(1) - b);
}

float4 colorBlend_Multiply(float4 bottom, float4 top) {
    if (top.r > 0) { bottom.r = bottom.r * top.r; }
    if (top.g > 0) { bottom.g = bottom.g * top.g; }
    if (top.b > 0) { bottom.b = bottom.b * top.b; }
//    bottom.r = bottom.r * top.r;
//    bottom.g = bottom.g * top.g;
//    bottom.b = bottom.b * top.b;
    return bottom;
}


// MARK: - Instances

bool getNthBit_I(int8_t value, uint8_t bitPosition) {
    // Check if the bit at the given position is set (1) or not (0)
    return (value & (1 << bitPosition)) != 0;
}


// recall buffer(x) is the Swift-defined buffer position for these vertices
vertex RasterizerData instanced_vertex_function(const VertexIn vertexIn [[ stage_in ]],
                                                constant SceneConstants &sceneConstants [[ buffer(1) ]],
                                                constant InstancedConstants *modelConstants [[ buffer(2) ]],
                                                constant BasicModelConstants &parentConstants [[ buffer(9) ]], // Constants of the parent rendered object this instance is attached to
                                                uint instanceId [[ instance_id ]] ) {
    RasterizerData rasterizerData;
    InstancedConstants constants = modelConstants[instanceId];
    float4x4 parentMatrix = identityMatrix;
    
    bool useParent = getNthBit_I(constants.flags, 0);
    if (useParent) {
        parentMatrix = parentConstants.modelMatrix;
    }
//    bool isMatchedSearchParent = getNthBit_I(parentConstants.flags, 2);
//    if (isMatchedSearchParent) {
//        const float scale = 5;
//        
//        const float scaledWidth = parentConstants.width * scale;
//        const float scaledHeight = parentConstants.height * scale;
//        const float widthDelta = scaledWidth - parentConstants.width;
//        const float heightDelta = scaledHeight - parentConstants.height;
//        parentMatrix = parentMatrix * scaleBy(float3(
//            scale,
//            scale,
//            1.0
//        ));
//        parentMatrix = parentMatrix * translationOf_I(float3(
//            scaledWidth,
//            scaledHeight,
//            50.0
//        ));
//    }
    
    const float scale = 3;
    bool isMatchedSearchInstance = getNthBit_I(constants.flags, 2);
    if (isMatchedSearchInstance) {
        constants.positionOffset.z += scale;
//        constants.scale.x += scale;
//        constants.scale.y += scale;
    }
    float4x4 instanceModel = float4x4(1.0) * translationOf_I(float3(
        constants.positionOffset.x,
        constants.positionOffset.y,
        constants.positionOffset.z
    ));
//    instanceModel = instanceModel * scaleBy(float3(
//        constants.scale.x,
//        constants.scale.y,
//        constants.scale.z
//    ));
    if (isMatchedSearchInstance) {
        constants.addedColorR = 255;
        constants.addedColorG = 0;
        constants.addedColorB = 0;
        
//        const float offsetX = constants.positionOffset.x;
//        const float offsetY = constants.positionOffset.y;
//        instanceModel = instanceModel
////        * rotateAboutX(cos(sceneConstants.totalGameTime))
////        * rotateAboutY(sin(sceneConstants.totalGameTime))
//        * translationOf_I(float3(
//            (sin(sceneConstants.totalGameTime) * constants.positionOffset.x),
//            (sin(sceneConstants.totalGameTime + constants.positionOffset.x)),
//            (sin(sceneConstants.totalGameTime + constants.positionOffset.x * 30))
//        ));
    }
    
    // Do test rotation
//    instanceModel = instanceModel
//    * rotateAboutX(cos(sceneConstants.totalGameTime))
//    * rotateAboutY(sin(sceneConstants.totalGameTime));
    
    rasterizerData.position =
      sceneConstants.projectionMatrix // camera
    * sceneConstants.viewMatrix       // viewport
    * parentMatrix                    // parent root transform
    * instanceModel                   // transforms
    * float4(vertexIn.position, 1)    // current position
    ;
    
    // Lol indexing into float4
    uint uvIndex = vertexIn.uvTextureIndex;
    float u = constants.textureDescriptorU[uvIndex];
    float v = constants.textureDescriptorV[uvIndex];
    rasterizerData.textureCoordinate = float2(u, v);
    
    rasterizerData.totalGameTime = sceneConstants.totalGameTime;
    rasterizerData.vertexPosition = vertexIn.position;
    rasterizerData.modelInstanceID = constants.bufferIndex;
    
    rasterizerData.addedColor = float4(
        constants.addedColorR / 255.0,
        constants.addedColorG / 255.0,
        constants.addedColorB / 255.0,
        1.0
    );
    rasterizerData.multipliedColor = float4(
        constants.multipliedColorR / 255.0,
        constants.multipliedColorG / 255.0,
        constants.multipliedColorB / 255.0,
        1.0
    );
    
    return rasterizerData;
}

// Instanced texturing and 'instanceID' coloring for hit-test/picking
fragment PickingTextureFragmentOut instanced_fragment_function(
   RasterizerData rasterizerData [[ stage_in ]],
   texture2d<float, access::sample> atlas [[texture(5)]])
{
    constexpr sampler sampler(coord::normalized,
                              address::clamp_to_zero,
                              filter::bicubic);
    
    float4 color = atlas.sample(sampler, rasterizerData.textureCoordinate);
    
    // TODO: Configure ordering
//    color = colorBlend_Overlay(color, rasterizerData.addedColor);
    color = colorBlend_Multiply(color, rasterizerData.multipliedColor);
    color = colorBlend_Add(color, rasterizerData.addedColor);
        
    PickingTextureFragmentOut out;
    out.mainColor = float4(color.r, color.g, color.b, color.a);
    out.pickingID = rasterizerData.modelInstanceID;
    
    return out;
}
