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
    simd_float4x4 modelMatrix;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // Compute specific
    simd_float2 textureSize;
    simd_float4 positionOffset;
    uint64_t unicodeHash;
    
    int instanceID;
    simd_float4 addedColor;
    simd_float4 multipliedColor;
    int bufferIndex; // index of self in cpu mtlbuffer
    int useParentMatrix; // 0 == no, 1 == yes, other == undefined
    int ignoreHover;     // 0 == no, 1 == yes, other == undefined
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
//    int codePointIndex;
    uint32_t codePoint;
    uint64_t unicodeHash;
    
//    int unicodeCodePointLength;
//    int totalUnicodeSequenceCount;
    
    // --- buffer indexing
//    int sourceUtf8BufferIndex;       // the previous character's index
    int sourceRenderableStringIndex; // the index for this glyph as it appears in its source, rendered 'text'
    
    // --- texture
//    simd_float4 foreground;
//    simd_float4 background;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // --- layout
    simd_float4 positionOffset;
//    simd_float4x4 modelMatrix;
    
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


#endif /* MetalLinkBridgingType_h */




