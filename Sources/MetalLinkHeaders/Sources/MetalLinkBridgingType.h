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

struct GlyphMapKernelAtlasIn {
    uint64_t unicodeHash;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
};

// MARK: -- GlyphMapKernel Outputs and Structs

struct GlyphMapKernelOut {
    // --- faux-nicode data
    enum GraphemeCategory graphemeCategory;
    uint codePointIndex;
    uint32_t codePoint;
    uint64_t unicodeHash;
    
    uint unicodeCodePointLength;
    uint totalUnicodeSequenceCount;
    uint32_t unicodeSlot1;
    uint32_t unicodeSlot2;
    uint32_t unicodeSlot3;
    uint32_t unicodeSlot4;
    uint32_t unicodeSlot5;
    uint32_t unicodeSlot6;
    uint32_t unicodeSlot7;
    uint32_t unicodeSlot8;
    uint32_t unicodeSlot9;
    uint32_t unicodeSlot10;
    
    // --- buffer indexing
    uint sourceUtf8BufferIndex;       // the previous character's index
    uint sourceRenderableStringIndex; // the index for this glyph as it appears in its source, rendered 'text'
    
    // --- texture
    simd_float4 foreground;
    simd_float4 background;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // --- layout
    float xOffset;
    float yOffset;
    float zOffset;
};

struct SceneConstants {
    float totalGameTime;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 pointerMatrix;
};

#endif /* MetalLinkBridgingType_h */




