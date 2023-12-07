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

// Metal-specific structures
#ifdef METAL_SHADER
#include <metal_stdlib>
using namespace metal;

struct GlyphMapKernelOut {
    // -- faux-nicode data
    enum GraphemeCategory graphemeCategory;
    uint codePointIndex;
    uint32_t codePoint;
    uint64_t unicodeHash;
    
    uint unicodeCodePointLength;
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
    
    // -- buffer indexing
    uint sourceUtf8BufferIndex;

    // -- texture
    simd_float4 foreground;
    simd_float4 background;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // <Atomics>
    metal::atomic<uint> totalUnicodeSequenceCount;
    
    // the index for this glyph as it appears in its source, rendered 'text'
    metal::atomic<uint> sourceRenderableStringIndex;
    
    // -- Layout
    metal::atomic<float> xOffset;
    metal::atomic<float> yOffset;
    metal::atomic<float> zOffset;
};

void GlyphMapKernelOut__Copy(
 const device GlyphMapKernelOut &source,
       device GlyphMapKernelOut &target
) {
    target.graphemeCategory = source.graphemeCategory;
    target.codePointIndex = source.codePointIndex;
    target.codePoint = source.codePoint;
    target.unicodeHash = source.unicodeHash;

    target.unicodeCodePointLength = source.unicodeCodePointLength;
    
    uint sourceCount = atomic_load_explicit(&source.totalUnicodeSequenceCount, memory_order_relaxed);
    atomic_store_explicit(&target.totalUnicodeSequenceCount, sourceCount, memory_order_relaxed);

    target.unicodeSlot1 = source.unicodeSlot1;
    target.unicodeSlot2 = source.unicodeSlot2;
    target.unicodeSlot3 = source.unicodeSlot3;
    target.unicodeSlot4 = source.unicodeSlot4;
    target.unicodeSlot5 = source.unicodeSlot5;
    target.unicodeSlot6 = source.unicodeSlot6;
    target.unicodeSlot7 = source.unicodeSlot7;
    target.unicodeSlot8 = source.unicodeSlot8;
    target.unicodeSlot9 = source.unicodeSlot9;
    target.unicodeSlot10 = source.unicodeSlot10;

    // -- buffer indexing
    target.sourceUtf8BufferIndex = source.sourceUtf8BufferIndex;

    // the index for this glyph as it appears in its source, rendered 'text'
    uint sourceIndex = atomic_load_explicit(&source.sourceRenderableStringIndex, memory_order_relaxed);
    atomic_store_explicit(&target.sourceRenderableStringIndex, sourceIndex, memory_order_relaxed);

    // -- texture
    target.foreground = source.foreground;
    target.background = source.background;

    target.textureSize = source.textureSize;
    target.textureDescriptorU = source.textureDescriptorU;
    target.textureDescriptorV = source.textureDescriptorV;

    // -- Layout
    float sourceXOffset = atomic_load_explicit(&source.xOffset, memory_order_relaxed);
    float sourceYOffset = atomic_load_explicit(&source.yOffset, memory_order_relaxed);
    float sourceZOffset = atomic_load_explicit(&source.zOffset, memory_order_relaxed);
    atomic_store_explicit(&target.xOffset, sourceXOffset, memory_order_relaxed);
    atomic_store_explicit(&target.yOffset, sourceYOffset, memory_order_relaxed);
    atomic_store_explicit(&target.zOffset, sourceZOffset, memory_order_relaxed);
}

#else
struct GlyphMapKernelOut {
    // faux-nicode data
    enum GraphemeCategory graphemeCategory;
    uint codePointIndex;
    uint32_t codePoint;
    uint64_t unicodeHash;
    
    uint unicodeCodePointLength;
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
    
    // buffer indexing
    uint sourceUtf8BufferIndex;             // the previous character's index
    
    // texture
    simd_float4 foreground;
    simd_float4 background;
    
    simd_float2 textureSize;
    simd_float4 textureDescriptorU;
    simd_float4 textureDescriptorV;
    
    // <|NON|Atomics>
    uint totalUnicodeSequenceCount;
    uint sourceRenderableStringIndex;       // the index for this glyph as it appears in its source, rendered 'text'
    
    // Layout
    float xOffset;
    float yOffset;
    float zOffset;
};
#endif

struct SceneConstants {
    float totalGameTime;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 pointerMatrix;
};

#endif /* MetalLinkBridgingType_h */




