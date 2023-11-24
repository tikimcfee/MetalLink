//
//  MetalLinkBridgingType.h
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 9/15/22.
//



#ifndef MetalLinkBridgingType_h
#define MetalLinkBridgingType_h
#include <simd/simd.h>
// TODO: Make `uint` type a bridged name.


struct BasicModelConstants {
    simd_float4x4 modelMatrix;
    simd_float4 color;
    uint textureIndex;
    uint pickingId;
};

struct InstancedConstants {
    simd_float4x4 modelMatrix;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    uint instanceID;
    simd_float4 addedColor;
    uint bufferIndex; // index of self in cpu mtlbuffer
    uint useParentMatrix; // 0 == no, 1 == yes, other == undefined
};

// Glyphees
struct GlyphMapKernelOut {
    uint32_t sourceValue;
    
    simd_float4 foreground;
    simd_float4 background;
    
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
};

struct SceneConstants {
    float totalGameTime;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 pointerMatrix;
};

#endif /* MetalLinkBridgingType_h */




