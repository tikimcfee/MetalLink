//
//  MetalLinkBridgingType.h
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 9/15/22.
//


#ifndef MetalLinkBridgingType_h
#define MetalLinkBridgingType_h

#include <simd/simd.h>

struct BasicModelConstants {
    simd_float4x4 modelMatrix;
    simd_float4 color;
    int pickingId;
};

struct InstancedConstants {
//    simd_float4x4 modelMatrix;
    
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // Compute specific
    simd_float2 textureSize;
    simd_float4 positionOffset;
    simd_float4 scale;
    uint64_t unicodeHash;
    
    uint8_t addedColorR;
    uint8_t addedColorG;
    uint8_t addedColorB;
    uint8_t multipliedColorR;
    uint8_t multipliedColorG;
    uint8_t multipliedColorB;
    
    /*
     MetalLinkGPUTypes.swift
     public enum Flag: UInt8 {
         case useParent
         case ignoreHover
     }
     */
    int bufferIndex; // index of self in cpu mtlbuffer
    uint8_t flags;
};

// MARK: - Glyphees

struct GlyphMapKernelAtlasIn {
    uint64_t unicodeHash;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
};

// MARK: -- GlyphMapKernel Outputs and Structs

struct GlyphMapKernelOut {
    uint32_t codePoint;
    uint64_t unicodeHash;

    // --- buffer indexing
    int sourceRenderableStringIndex; // the index for this glyph as it appears in its source, rendered 'text'
    
    // --- texture
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // --- layout
    simd_float4 positionOffset;
    
    int rendered;
    int foundLineStart;
    int LineBreaksAtRender;
};

struct SceneConstants {
    float totalGameTime;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 pointerMatrix;
};

enum GraphemeStatus {
    SINGLE = 0,
    START,
    MIDDLE,
    END
};

enum GraphemeCategory {
    // -- 'utf32GlyphSingle`
    //- 0 : "single"
    utf32GlyphSingle = 0,
    
    // -- 'utf32GlyphEmojiPrefix`
    //- 1 : "start"
    //- 2 : "middle"
    //- 3 : "middle"
    //- 4 : "end"
    utf32GlyphEmojiPrefix,
    
    // -- 'utf32GlyphTag`
    //- 14 : "start"
    //- 15 : "end"
    //- 16 : "middle"
    //- 17 : "end"
    utf32GlyphTag,
    
    // -- 'utf32GlyphEmojiSingle`
    //- 40 : "start"
    //- 41 : "middle"
    //- 42 : "end"
    //- 43 : "end"
    utf32GlyphEmojiSingle,
    
    // -- 'utf32GlyphData`
    //- 0 : "single"
    utf32GlyphData
};

#endif /* MetalLinkBridgingType_h */
