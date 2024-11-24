#define METAL_SHADER
#include <metal_stdlib>

//#include "include/MetalLinkResources.h"
#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

// MARK: - Simple helpers

float4x4 translationOf(float3 offset) {
    return float4x4(float4( 1, 0, 0, 0),
                    float4( 0, 1, 0, 0),
                    float4( 0, 0, 1, 0),
                    float4(offset.x, offset.y, offset.z, 1));
}

float2 unitSize(float2 source) {
    float unitWidth = 1.0 / source.x;
    float unitHeight = 1.0 / source.y;
    return float2(min(source.x * unitHeight, 1.0),
                  min(source.y * unitWidth, 1.0));
}

bool getNthBit(int8_t value, uint8_t bitPosition) {
    // Check if the bit at the given position is set (1) or not (0)
    return (value & (1 << bitPosition)) != 0;
}

//int8_t modifyNthBit(int8_t value, uint8_t bitPosition, bool set) {
//    if (set) {
//        // Set the bit if 'set' is true
//        return value | (1 << bitPosition);
//    } else {
//        // Clear the bit if 'set' is false
//        return value & ~(1 << bitPosition);
//    }
//}

uint8_t modifyNthBit(uint8_t value, uint8_t bitPosition, bool set) {
    bitPosition = bitPosition & 0x7;
    
    if (set) {
        return value | (1u << bitPosition);
    } else {
        return value & ~(1u << bitPosition);
    }
}


// Safely get byte at index, handling bounds check
uint8_t getByte(
    const device uint8_t* bytes,
    uint index,
    uint utf8Size
) {
    if (index < 0 || index >= utf8Size) {
        return 0; // Invalid, return 0 byte
    }
    return bytes[index];
}

// MARK: - faux-nicode parsing helpers

// Get the expected byte sequence count from index in buffer.
// -- return: 1-4 on success, something else if things go wrong.
int sequenceCountForByteAtIndex(
   const device uint8_t* bytes,
   uint index,
   uint utf8Size
) {
    uint8_t byteAtIndex = getByte(bytes, index, utf8Size);
    if (byteAtIndex == 0) { return 0; }
    
    if ((byteAtIndex & 0x80) == 0x00) {
        return 1;
    }
    if ((byteAtIndex & 0xE0) == 0xC0) {
        return 2;
    }
    if ((byteAtIndex & 0xF0) == 0xE0) {
        return 3;
    }
    if ((byteAtIndex & 0xF8) == 0xF0) {
        return 4;
    }
    return 0;
}

// A fakeout function to give us a heuristic to pattern match
// The pattern will be:

GraphemeStatus getDecodeStatus(uint8_t byte) {
    if ((byte & 0x80) == 0) {
        return SINGLE; // Single byte codepoint
    }
    else if ((byte & 0xC0) == 0xC0) {
        return START; // Start of multi-byte sequence
    }
    else if ((byte & 0x20) == 0) {
        return MIDDLE; // Middle of sequence
    }
    return END; // End of sequence (default...)
}

GraphemeCategory categoryForGraphemeBytes(
    uint8_t firstByte,
    uint8_t secondByte,
    uint8_t thirdByte,
    uint8_t fourthByte
) {
    GraphemeStatus byteStatus1 = getDecodeStatus(firstByte);
    GraphemeStatus byteStatus2 = getDecodeStatus(secondByte);
    GraphemeStatus byteStatus3 = getDecodeStatus(thirdByte);
    GraphemeStatus byteStatus4 = getDecodeStatus(fourthByte);
    
    // start/middle/middle/end == emoji group 'prefix';
    if (
        byteStatus1 == START
     && byteStatus2 == MIDDLE
     && byteStatus3 == MIDDLE
     && (byteStatus4 == END || byteStatus4 == MIDDLE)
    ) {
        return utf32GlyphEmojiPrefix;
    }
    // start/end/middle/end == tag;
    else if (
        byteStatus1 == START
     && byteStatus2 == END
     && byteStatus3 == MIDDLE
     && byteStatus4 == END
    ) {
        return utf32GlyphTag;
    }
    // start/middle/end/end == emoji single;
    else if (
        byteStatus1 == START
     && byteStatus2 == MIDDLE
     && byteStatus3 == END
     && byteStatus4 == END
    ) {
        return utf32GlyphEmojiSingle;
    }
    
    // anything not early-returned as `data` is a glyph;
    return utf32GlyphSingle;
}

uint32_t decodeByteSequence_2(
    uint8_t firstByte,
    uint8_t secondByte
) {
    return ((firstByte  & 0x1F) << 6)
          | (secondByte & 0x3F);
}

uint32_t decodeByteSequence_3(
    uint8_t firstByte,
    uint8_t secondByte,
    uint8_t thirdByte
) {
    return ((firstByte  & 0x0F) << 12)
         | ((secondByte & 0x3F) << 6)
         |  (thirdByte  & 0x3F);
}

uint32_t decodeByteSequence_4(
    uint8_t firstByte,
    uint8_t secondByte,
    uint8_t thirdByte,
    uint8_t fourthByte
) {
    return ((firstByte  & 0x07) << 18)
         | ((secondByte & 0x3F) << 12)
         | ((thirdByte  & 0x3F) << 6)
         |  (fourthByte & 0x3F);
}

uint32_t codePointForSequence(
    uint8_t firstByte,
    uint8_t secondByte,
    uint8_t thirdByte,
    uint8_t fourthByte,
    int sequenceCount
) {
    switch (sequenceCount) {
        case 1:
            return firstByte;
        case 2:
            return decodeByteSequence_2(firstByte, secondByte);
        case 3:
            return decodeByteSequence_3(firstByte, secondByte, thirdByte);
        case 4:
            return decodeByteSequence_4(firstByte, secondByte, thirdByte, fourthByte);
    }
    return 0;
}

// MARK: - Compute hash for given kernel output glyph
// See:
/*
 // SwiftGlyph
 public extension Character {
     var glyphComputeHash: UInt64 {
 */

constant uint64_t hashPrime = 31;
constant uint64_t hashModulo = 1000000;
void accumulateGlyphHashKernel(
    device GlyphMapKernelOut* utf32Buffer,
    uint index,
    uint32_t data
) {
    GlyphMapKernelOut out = utf32Buffer[index];
    
    uint64_t hash = out.unicodeHash;
    hash = (hash * hashPrime + data) % hashModulo;
    out.unicodeHash = hash;
    
    utf32Buffer[index] = out;
    
}

// MARK: -- <> Magix fauxnicode looking/lookbehind handling

void attemptUnicodeScalarSetLookahead(
   const device uint8_t* utf8Buffer,
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
   constant     uint* utf8BufferSize,
                GraphemeCategory category,
                uint32_t codePoint
) {
    // Grab lookahead data
    uint lookaheadStartIndex = id + 4;
    uint8_t lookahead1 = getByte(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
    uint8_t lookahead2 = getByte(utf8Buffer, lookaheadStartIndex + 1, *utf8BufferSize);
    uint8_t lookahead3 = getByte(utf8Buffer, lookaheadStartIndex + 2, *utf8BufferSize);
    uint8_t lookahead4 = getByte(utf8Buffer, lookaheadStartIndex + 3, *utf8BufferSize);
    
    // Grab the category of the next utf32 group
    GraphemeCategory lookaheadCategory = categoryForGraphemeBytes(lookahead1, lookahead2, lookahead3, lookahead4);
    
    // Data and single-byte glyphs just return their initial bytes;
    // this particular lookahead is done.
    if (category == utf32GlyphSingle || category == utf32GlyphData) {
        accumulateGlyphHashKernel(utf32Buffer, id, codePoint);
    }
    
    // If it's an emoji-single, then we just need to set the first 4 bytes, we're done
    else if (category == utf32GlyphEmojiSingle) {
        accumulateGlyphHashKernel(utf32Buffer, id, codePoint);
    }
    
    // If it's a prefix, we do some work
    else if (category == utf32GlyphEmojiPrefix) {
        // We assume that if we have two sequential 'prefix', it's actually one emoji, so set the second slot
        if (lookaheadCategory == utf32GlyphEmojiPrefix) {
            uint8_t lookbehind1 = getByte(utf8Buffer, id - 4, *utf8BufferSize);
            uint8_t lookbehind2 = getByte(utf8Buffer, id - 3, *utf8BufferSize);
            uint8_t lookbehind3 = getByte(utf8Buffer, id - 2, *utf8BufferSize);
            uint8_t lookbehind4 = getByte(utf8Buffer, id - 1, *utf8BufferSize);
            GraphemeCategory lookbehindCategory = categoryForGraphemeBytes(lookbehind1, lookbehind2, lookbehind3, lookbehind4);
            
            // .. but if lookbehind is also a prefix, it means a new emoji group will start, and we're data. probably.
            if (lookbehindCategory == utf32GlyphEmojiPrefix) {
                return;
            }
            
            // otherwise we're the glyph leader so store the points
            accumulateGlyphHashKernel(utf32Buffer, id, codePoint);
            
            uint32_t nextCodePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            accumulateGlyphHashKernel(utf32Buffer, id, nextCodePoint);
        }
        
        // If it's a tag, we start doing some special lookahead magic...
        else if (lookaheadCategory == utf32GlyphTag) {
            accumulateGlyphHashKernel(utf32Buffer, id, codePoint);
            
            // Start at the next slot and begin writing for each tag
            int writeSlot = 2;
            int lookaheadSequenceCount = sequenceCountForByteAtIndex(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
            uint32_t codePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            while (lookaheadCategory == utf32GlyphTag && writeSlot <= 10) {
                accumulateGlyphHashKernel(utf32Buffer, id, codePoint);
                
                // Move to the next slot and lookahead start
                writeSlot += 1;
                lookaheadStartIndex += 4;
                
                // grab the bytes, the sequence, and the category to write next, if we should
                lookahead1 = getByte(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
                lookahead2 = getByte(utf8Buffer, lookaheadStartIndex + 1, *utf8BufferSize);
                lookahead3 = getByte(utf8Buffer, lookaheadStartIndex + 2, *utf8BufferSize);
                lookahead4 = getByte(utf8Buffer, lookaheadStartIndex + 3, *utf8BufferSize);
                
                lookaheadSequenceCount = sequenceCountForByteAtIndex(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
                codePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, lookaheadSequenceCount);

                lookaheadCategory = categoryForGraphemeBytes(lookahead1, lookahead2, lookahead3, lookahead4);
            }
        }
        
        // Otherwise, just return, we don't want to set any other data.
    }
}

// MARK: -- Layout v1
/*
 Unicode   UInt32  Name                    Line Break   Platform
 U+000A    10      Line Feed (LF)          [\n]         *nix, macOS
 U+000B    11      Vertical Tab (VT)
 U+000C    12      Form Feed (FF)
 U+000D    13      Carriage Return (CR)    [\r\n]       Windows
 U+0085    133     Next Line (NEL)
 U+2028    8232    Line Separator
 U+2029    8233    Paragraph Separator
 */

uint indexOfCharacterBefore(
   const device uint8_t* utf8Buffer,
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
   constant     uint* utf8BufferSize
) {
    // If out of bounds, return id
    if (id < 0 || id > *utf8BufferSize) {
        return id;
    }
    
    uint foundIndex = id - 1;
    bool inBounds = foundIndex >= 0 && foundIndex < *utf8BufferSize;
    while (inBounds) {
        if (utf32Buffer[foundIndex].unicodeHash != 0) {
            return foundIndex;
        }
        foundIndex -= 1;
        inBounds = foundIndex >= 0 && foundIndex < *utf8BufferSize;
    }
    return id;
}

uint indexOfCharacterAfter(
   const device uint8_t* utf8Buffer,
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
   constant     uint* utf8BufferSize
) {
    // If out of bounds, return id
    if (id < 0 || id > *utf8BufferSize) {
        return id;
    }
    
    uint foundIndex = id + 1;
    bool inBounds = foundIndex >= 0 && foundIndex < *utf8BufferSize;
    while (inBounds) {
        if (utf32Buffer[foundIndex].unicodeHash != 0) {
            return foundIndex;
        }
        foundIndex += 1;
        inBounds = foundIndex >= 0 && foundIndex < *utf8BufferSize;
    }
    return id;
}

/* Layout
 - Iterate backward in the output buffer.
    - get last glyph
        - If it's a character, add it's width to the current line.
        - If it's a line break, don't add width, and drop down y-offset
            - also, we stop adding width; we're at the x-offset we want.
    - if we're off the max width of a 'page'
        - drop to the leftmost of the page, drop back in depth, and restart line
    - if we're off the max height of a 'page'
        - drop y offset to 0 (top), set the x-offset to horizontal page break (+88), and increase max page width
        -
     
*/
struct GridOffset {
    float x;      // Adjusted x position
    float y;      // Adjusted y position
    float z;      // Z-depth
    int xPages;   // How many horizontal pages we've moved
    int yPages;   // How many vertical pages we've moved
};


struct PageOffset {
    float x;      // Adjusted x position
    float y;      // Adjusted y position
    float z;      // Z-depth
    int xPages;   // How many horizontal pages we've moved
    int yPages;   // How many vertical pages we've moved
};

PageOffset calculatePageOffsets(
    float xPosition,
    float yPosition,
    float zPosition,
    float pageWidth     = 88,
    float pageWidthPad  = 10,
    float pageHeight    = -150,
    float pageHeightPad = 20,
    int pagesWide       = 5
) {
    PageOffset result;
    
    // Calculate vertical page and offset
    result.yPages = int(abs(yPosition) / pageHeight);
    result.y = yPosition + (pageHeight * result.yPages);
    // This lets the pages stack vertically as well
//    result.y = result.y + (pageHeight - pageHeightPad) * abs(int(result.yPages / pagesWide));
    
    // Calculate horizontal page and offset
    result.xPages = int(xPosition / pageWidth);
    result.x = fmod(xPosition, pageWidth);
    
    // Mod the position above, and then offset it by the page.
    result.x -= (pageWidth + pageWidthPad) * fmod(float(result.yPages), pagesWide);
    
    // Calculate z offset
    float zFromVertical = int(result.yPages / pagesWide) * 32.0;
    float zFromHorizontal = result.xPages * -4.0;
    
    result.z = zPosition + zFromVertical + zFromHorizontal;
    
    return result;
}

kernel void utf32GlyphMap_FastLayout_Paginate(
    const device uint8_t* utf8Buffer                [[buffer(0)]],
    device       GlyphMapKernelOut* utf32Buffer     [[buffer(1)]],
    device       GlyphMapKernelAtlasIn* atlasBuffer [[buffer(2)]],
                 uint id                            [[thread_position_in_grid]],
    constant     uint* utf8BufferSize               [[buffer(3)]],
    constant     uint* atlasBufferSize              [[buffer(4)]],
    constant     uint* utf32BufferSize              [[buffer(5)]]
) {
    uint localSize = *utf32BufferSize;
    uint offsetMax = localSize - 1;
    if (id > offsetMax) {
        return;
    }
    
    GlyphMapKernelOut out = utf32Buffer[id];
    if (out.unicodeHash == 0) {
        return;
    }
    
    PageOffset pageOffsets = calculatePageOffsets(
        out.positionOffset.x,
        out.positionOffset.y,
        out.positionOffset.z
    );
    
    out.positionOffset.x = pageOffsets.x;
    out.positionOffset.y = pageOffsets.y;
    out.positionOffset.z = pageOffsets.z;
    
    utf32Buffer[id] = out;
}

kernel void utf32GlyphMap_FastLayout(
    const device uint8_t* utf8Buffer                [[buffer(0)]],
    device       GlyphMapKernelOut* utf32Buffer     [[buffer(1)]],
    device       GlyphMapKernelAtlasIn* atlasBuffer [[buffer(2)]],
                 uint id                            [[thread_position_in_grid]],
    constant     uint* utf8BufferSize               [[buffer(3)]],
    constant     uint* atlasBufferSize              [[buffer(4)]],
    constant     uint* utf32BufferSize              [[buffer(5)]]
) {
    uint localSize = *utf32BufferSize;
    uint offsetMax = localSize - 1;
    if (id > offsetMax) {
        return;
    }
    
    GlyphMapKernelOut out = utf32Buffer[id];
    if (out.unicodeHash == 0) {
        return;
    }
    
    int shouldContinueBacktrack = true;
    int backtrackCount = 0;
    uint previousGlyphIndex = id;
    previousGlyphIndex = indexOfCharacterBefore(
        utf8Buffer,
        utf32Buffer,
        previousGlyphIndex,
        utf8BufferSize
    );
    
    while (shouldContinueBacktrack) {
        // Early return; no previous, no previous to read.
        if (previousGlyphIndex == id) {
            shouldContinueBacktrack = false;
            continue;
        }
        
        // --- Do the offset mathing
        GlyphMapKernelOut previousGlyph = utf32Buffer[previousGlyphIndex];
        
        float previousX = previousGlyph.positionOffset.x;
        float previousY = previousGlyph.positionOffset.y;
        float previousSizeX = previousGlyph.textureSize.x;
        float previousSizeY = previousGlyph.textureSize.y;
        int previousRendered = previousGlyph.rendered;
        int previousFoundStart = previousGlyph.foundLineStart;
        
        if (
            previousRendered == true
            && backtrackCount > 128
        ) {
            if (previousGlyph.codePoint == '\n') {
                if (out.foundLineStart == false) {
                    out.positionOffset.x = 0;
                }
                out.positionOffset.y -= previousSizeY;
                out.foundLineStart = true;
            }
            
            out.positionOffset.y += previousY;
            
            if (out.foundLineStart == false) {
                out.positionOffset.x += previousX;
                out.positionOffset.x += previousSizeX;
            }
            
            out.foundLineStart = previousFoundStart || out.foundLineStart;
            shouldContinueBacktrack = false;
        }
        else {
            if (previousGlyph.codePoint == '\n') {
                out.positionOffset.y -= previousSizeY;
                out.foundLineStart = true;
            }
            if (out.foundLineStart == false) {
                out.positionOffset.x += previousSizeX;
            }
        }
        
        backtrackCount += 1;
        
        // --- Do the iterator backtracking
        // Grab the current index, and check the last one
        if (shouldContinueBacktrack) {
            uint currentIndex = previousGlyphIndex;
            previousGlyphIndex = indexOfCharacterBefore(utf8Buffer,
                                                        utf32Buffer,
                                                        previousGlyphIndex,
                                                        utf8BufferSize);
            
            // Stop backtracking if the index we get back as 'before' is us, which means we're done.
            // Also said, you should keep going iff the previous index is not the current index.
            shouldContinueBacktrack = previousGlyphIndex != currentIndex
                                   && previousGlyphIndex >= 0
                                   && previousGlyphIndex <* utf8BufferSize;
        }
    }
    
    utf32Buffer[id] = out;
    utf32Buffer[id].rendered = true;
}


// MARK: [Parsing and mapping]
// MARK: -- Direct mapping from utf8 -> GlyphMapKernelOut

kernel void utf8ToUtf32Kernel(
    const device uint8_t* utf8Buffer            [[buffer(0)]],
    device       GlyphMapKernelOut* utf32Buffer [[buffer(1)]],
                 uint id                        [[thread_position_in_grid]],
    constant     uint* utf8BufferSize           [[buffer(2)]]
) {
    // Boundary check
    if (id > *utf8BufferSize) {
        return;
    }
    
    // Determine the number of bytes in the UTF-8 character
    int sequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
    if (sequenceCount < 1 || sequenceCount > 4) {
        // If it has a weird sequence length, it's glyph data, break early
        return;
    }
    
    // Grab 4 bytes from the buffer; we're assuming 0 is returned on out-of-bounds.
    uint8_t firstByte  = getByte(utf8Buffer, id + 0, *utf8BufferSize);
    uint8_t secondByte = getByte(utf8Buffer, id + 1, *utf8BufferSize);
    uint8_t thirdByte  = getByte(utf8Buffer, id + 2, *utf8BufferSize);
    uint8_t fourthByte = getByte(utf8Buffer, id + 3, *utf8BufferSize);
    
    uint32_t codePoint = codePointForSequence(firstByte, secondByte, thirdByte, fourthByte, sequenceCount);
    GraphemeCategory category = categoryForGraphemeBytes(firstByte, secondByte, thirdByte, fourthByte);
    
    utf32Buffer[id].codePoint = codePoint;
    
    attemptUnicodeScalarSetLookahead(
       utf8Buffer,
       utf32Buffer,
       id,
       utf8BufferSize,
       category,
       codePoint
     );
}

// MARK: -- Atlas texture mapping from utf8 -> GlyphMapKernelOut

kernel void processNewUtf32AtlasMapping(
    device       GlyphMapKernelOut* unprocessedGlyphs     [[buffer(0)]],
                 uint id                                  [[thread_position_in_grid]],
    device       GlyphMapKernelOut* cleanGlyphBuffer      [[buffer(1)]],
    constant     uint* unprocessedSize                    [[buffer(2)]],
    constant     uint* cleanOutputSize                    [[buffer(3)]]
) {
    if (id < 0 || id > *unprocessedSize) {
        return;
    }
    GlyphMapKernelOut glyphCopy = unprocessedGlyphs[id];
    if (glyphCopy.unicodeHash == 0) {
        return;
    }
    
    uint targetBufferIndex = glyphCopy.sourceRenderableStringIndex;
    if (targetBufferIndex < 0 || targetBufferIndex > *cleanOutputSize) {
        return;
    }
    
    cleanGlyphBuffer[targetBufferIndex] = glyphCopy;
}

// Function to atomically set the minimum value in a buffer
void atomicMin(
   device atomic_float *atomicBuffer,
   uint index,
   float newValue
) {
    float oldValue;
    // Loop to attempt the atomic min operation until it succeeds
    do {
        // Load the current value from the atomic buffer
        oldValue = atomic_load_explicit(&atomicBuffer[index], memory_order_relaxed);

        // If the new value is not smaller than the current value, no need to swap
        if (newValue >= oldValue) {
            return;
        }
        
        // Attempt to set the atomic buffer to the new minimum value
    } while (!atomic_compare_exchange_weak_explicit(&atomicBuffer[index],
                                                    &oldValue,
                                                    newValue,
                                                    memory_order_relaxed,
                                                    memory_order_relaxed));
}
              
// Function to atomically set the maximum value in a buffer
void atomicMax(
   device atomic_float *atomicBuffer,
   uint index,
   float newValue
) {
    float oldValue;
    // Loop to attempt the atomic max operation until it succeeds
    do {
        // Load the current value from the atomic buffer
        oldValue = atomic_load_explicit(&atomicBuffer[index], memory_order_relaxed);

        // If the new value is not larger than the current value, no need to swap
        if (newValue <= oldValue) {
            return;
        }
        
        // Attempt to set the atomic buffer to the new maximum value
    } while (!atomic_compare_exchange_weak_explicit(&atomicBuffer[index],
                                                    &oldValue,
                                                    newValue,
                                                    memory_order_relaxed,
                                                    memory_order_relaxed));
}

kernel void searchGlyphs_debug(
    uint id                                  [[thread_position_in_grid]],
    device       InstancedConstants* targetConstants      [[buffer(0)]],
    constant     uint* constantsCount                     [[buffer(1)]],
    constant     uint64_t* searchInputHashes              [[buffer(2)]],
    constant     uint* searchInputLength                  [[buffer(3)]],
    device       atomic_uint* foundMatch                  [[buffer(4)]],  // Use atomic_uint for thread safety
    device       uint64_t* debug                          [[buffer(5)]]
) {
    const uint searchLength = *searchInputLength;
    const uint count = *constantsCount;

    // Bounds check
    if ((id + searchLength) > count) {
        return;
    }

    InstancedConstants out;
    uint searchHash;
    bool matches = true;

    // Compare each hash in the search query
    for (uint i = 0; i < searchLength; i++) {
        out = targetConstants[id + i];
        searchHash = searchInputHashes[i];
        if (out.unicodeHash != searchHash) {
            matches = false;
            break;  // Exit the loop on mismatch
        } else {
            debug[id + i] = searchHash;
        }
    }

    if (matches) {
        // Update flags in the matching range
        for (uint i = 0; i < searchLength; i++) {
            out = targetConstants[id + i];
            out.flags = modifyNthBit(out.flags, 2, true);  // Modify the 2nd bit of the flag
            targetConstants[id + i] = out;
        }

        // Atomically set foundMatch to true
        atomic_store_explicit(foundMatch, 1, memory_order_relaxed);
    }
}

kernel void searchGlyphs(
    uint id                                  [[thread_position_in_grid]],
    device       InstancedConstants* targetConstants      [[buffer(0)]],
    constant     uint* constantsCount                     [[buffer(1)]],
    constant     uint64_t* searchInputHashes              [[buffer(2)]],
    constant     uint* searchInputLength                  [[buffer(3)]],
    device       atomic_uint* foundMatch                  [[buffer(4)]]
//    device       uint64_t* debug                          [[buffer(5)]]
) {
    const uint searchLength = *searchInputLength;
    const uint count = *constantsCount;

    // Bounds check
    if ((id + searchLength) > count) {
        return;
    }

    InstancedConstants out;
    uint searchHash;
    bool matches = true;

    // Compare each hash in the search query
    for (uint i = 0; i < searchLength; i++) {
        out = targetConstants[id + i];
        searchHash = searchInputHashes[i];
        if (out.unicodeHash != searchHash) {
            matches = false;
            break;  // Exit the loop on mismatch
        }
    }

    if (matches) {
        // Update flags in the matching range
        for (uint i = 0; i < searchLength; i++) {
            out = targetConstants[id + i];
            out.flags = modifyNthBit(out.flags, 2, true);  // Modify the 2nd bit of the flag
            targetConstants[id + i] = out;
        }

        // Atomically set foundMatch to true
        atomic_store_explicit(foundMatch, 1, memory_order_relaxed);
    }
}


kernel void clearSearchGlyphs(
                 uint id                                  [[thread_position_in_grid]],
    device       InstancedConstants* targetConstants      [[buffer(0)]],
    constant     uint* constantsCount                     [[buffer(1)]]
) {
    if (id > *constantsCount) {
        return;
    }
    
    InstancedConstants out = targetConstants[id];
    out.flags = modifyNthBit(out.flags, 2, false);
    targetConstants[id] = out;
}


kernel void blitGlyphsIntoConstants(
    device       GlyphMapKernelOut* unprocessedGlyphs     [[buffer(0)]],
                 uint id                                  [[thread_position_in_grid]],
    device       InstancedConstants* targetConstants      [[buffer(1)]],
    constant     uint* unprocessedSize                    [[buffer(2)]],
    constant     uint* expectedCharacterCount             [[buffer(3)]],
    device       atomic_uint* instanceCounter             [[buffer(4)]],
    
    device       atomic_float* minX                       [[buffer(5)]],
    device       atomic_float* minY                       [[buffer(6)]],
    device       atomic_float* minZ                       [[buffer(7)]],
                                    
    device       atomic_float* maxX                       [[buffer(8)]],
    device       atomic_float* maxY                       [[buffer(9)]],
    device       atomic_float* maxZ                       [[buffer(10)]]
) {
    if (id >= *unprocessedSize) {
        return;
    }
    GlyphMapKernelOut glyphCopy = unprocessedGlyphs[id];
//    if (glyphCopy.unicodeHash == 0) {
//        return;
//    }
    
    uint targetBufferIndex = glyphCopy.sourceRenderableStringIndex;
    if (targetBufferIndex >= *expectedCharacterCount) {
        return;
    }
    
    InstancedConstants out = targetConstants[targetBufferIndex];
    
    out.bufferIndex = targetBufferIndex;
    out.addedColorR = 0;
    out.addedColorG = 0;
    out.addedColorB = 0;
    out.multipliedColorR = 255;
    out.multipliedColorG = 255;
    out.multipliedColorB = 255;
    
    out.flags = modifyNthBit(out.flags, 0, true);
    out.flags = modifyNthBit(out.flags, 1, false);
    out.flags = modifyNthBit(out.flags, 2, false);
    out.unicodeHash = glyphCopy.unicodeHash;
    out.textureDescriptorU = glyphCopy.textureDescriptorU;
    out.textureDescriptorV = glyphCopy.textureDescriptorV;
    out.textureSize = glyphCopy.textureSize;
    out.positionOffset = glyphCopy.positionOffset;
    out.scale = float4(1, 1, 1, 1);
    targetConstants[targetBufferIndex] = out;
    
    atomicMin(minX, 0, glyphCopy.positionOffset.x - glyphCopy.textureSize.x / 2.0);
    atomicMin(minY, 0, glyphCopy.positionOffset.y - glyphCopy.textureSize.y / 2.0);
    atomicMin(minZ, 0, glyphCopy.positionOffset.z);
    
    atomicMax(maxX, 0, glyphCopy.positionOffset.x + glyphCopy.textureSize.x / 2.0);
    atomicMax(maxY, 0, glyphCopy.positionOffset.y + glyphCopy.textureSize.x / 2.0);
    atomicMax(maxZ, 0, glyphCopy.positionOffset.z);
}

kernel void blitColorsIntoConstants(
    uint         id                                       [[thread_position_in_grid]],
    device       simd_float4* colors                      [[buffer(0)]],
    device       InstancedConstants* targetConstants      [[buffer(1)]],
    constant     uint* colorsSize                         [[buffer(2)]]
) {
    if (id < 0 || id >= *colorsSize) {
        return;
    }
    // TODO: Multiple color values
    targetConstants[id].multipliedColorR = colors[id].x * 255.0;
    targetConstants[id].multipliedColorG = colors[id].y * 255.0;
    targetConstants[id].multipliedColorB = colors[id].z * 255.0;
}

kernel void utf8ToUtf32KernelAtlasMapped(
    const device uint8_t* utf8Buffer                [[buffer(0)]],
    device       GlyphMapKernelOut* utf32Buffer     [[buffer(1)]],
    device       GlyphMapKernelAtlasIn* atlasBuffer [[buffer(2)]],
                 uint id                            [[thread_position_in_grid]],
    constant     uint* utf8BufferSize               [[buffer(3)]],
    constant     uint* atlasBufferSize              [[buffer(4)]],
    device       atomic_uint* totalCharacterCount   [[buffer(5)]]
) {
    // Boundary check
    if (id > *utf8BufferSize) {
        return;
    }
    
    // Determine the number of bytes in the UTF-8 character
    int sequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
    if (sequenceCount < 1 || sequenceCount > 4) {
        // If it has a weird sequence length, it's glyph data, break early
        return;
    }
    
    // Grab 4 bytes from the buffer; we're assuming 0 is returned on out-of-bounds.
    uint8_t firstByte  = getByte(utf8Buffer, id + 0, *utf8BufferSize);
    uint8_t secondByte = getByte(utf8Buffer, id + 1, *utf8BufferSize);
    uint8_t thirdByte  = getByte(utf8Buffer, id + 2, *utf8BufferSize);
    uint8_t fourthByte = getByte(utf8Buffer, id + 3, *utf8BufferSize);
    
    uint32_t codePoint = codePointForSequence(firstByte, secondByte, thirdByte, fourthByte, sequenceCount);
    GraphemeCategory category = categoryForGraphemeBytes(firstByte, secondByte, thirdByte, fourthByte);
    
    GlyphMapKernelOut out = utf32Buffer[id];
    
    out.codePoint = codePoint;
    
    utf32Buffer[id] = out;
    
    attemptUnicodeScalarSetLookahead(
       utf8Buffer,
       utf32Buffer,
       id,
       utf8BufferSize,
       category,
       codePoint
     );
    
    uint64_t hash = utf32Buffer[id].unicodeHash;
    
    if (hash > 0 && hash < *atlasBufferSize) {
        /* MARK: Buffer compressomaticleanerating [Pass 1]
         Set the buffer index we started at. Set the original source index, to track both states. lolmemorywhat
        */
        GlyphMapKernelAtlasIn atlasData = atlasBuffer[hash];
        GlyphMapKernelOut out = utf32Buffer[id];
        
        out.textureSize = unitSize(atlasData.textureSize);
        out.textureDescriptorU = atlasData.textureDescriptorU;
        out.textureDescriptorV = atlasData.textureDescriptorV;
        out.sourceRenderableStringIndex = id;
        
        utf32Buffer[id] = out;
        
        atomic_fetch_add_explicit(totalCharacterCount, 1, memory_order_relaxed);
    }
}
