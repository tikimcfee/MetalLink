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

// TODO: I mean you could just keep a count and hash it all at once but then debugging is just lulz
uint getUnicodeLengthFromSlots(
   device       GlyphMapKernelOut* utf32Buffer,
                uint id
) {
    if (utf32Buffer[id].unicodeSlot10 != 0) { return 10; }
    if (utf32Buffer[id].unicodeSlot9 != 0) { return 9; }
    if (utf32Buffer[id].unicodeSlot8 != 0) { return 8; }
    if (utf32Buffer[id].unicodeSlot7 != 0) { return 7; }
    if (utf32Buffer[id].unicodeSlot6 != 0) { return 6; }
    if (utf32Buffer[id].unicodeSlot5 != 0) { return 5; }
    if (utf32Buffer[id].unicodeSlot4 != 0) { return 4; }
    if (utf32Buffer[id].unicodeSlot3 != 0) { return 3; }
    if (utf32Buffer[id].unicodeSlot2 != 0) { return 2; }
    if (utf32Buffer[id].unicodeSlot1 != 0) { return 1; }
    return 0;
}

void setDataOnSlotAtIndex(
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
                int slotNumber,
                uint32_t data
) {
    switch (slotNumber) {
        case 1:
            utf32Buffer[id].unicodeSlot1 = data;
            break;
        case 2:
            utf32Buffer[id].unicodeSlot2 = data;
            break;
        case 3:
            utf32Buffer[id].unicodeSlot3 = data;
            break;
        case 4:
            utf32Buffer[id].unicodeSlot4 = data;
            break;
        case 5:
            utf32Buffer[id].unicodeSlot5 = data;
            break;
        case 6:
            utf32Buffer[id].unicodeSlot6 = data;
            break;
        case 7:
            utf32Buffer[id].unicodeSlot7 = data;
            break;
        case 8:
            utf32Buffer[id].unicodeSlot8 = data;
            break;
        case 9:
            utf32Buffer[id].unicodeSlot9 = data;
            break;
        case 10:
            utf32Buffer[id].unicodeSlot10 = data;
            break;
    }
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

uint64_t glyphHashKernel(
    device GlyphMapKernelOut* utf32Buffer,
    uint index
) {
    const uint64_t prime = 31;
    uint64_t hash = 0;
    uint64_t slot1 = utf32Buffer[index].unicodeSlot1;
    if (slot1 != 0) {
        hash = (hash * prime + slot1) % 1000000;
    } else { return hash; }

    uint64_t slot2 = utf32Buffer[index].unicodeSlot2;
    if (slot2 != 0) {
        hash = (hash * prime + slot2) % 1000000;
    } else { return hash; }
    
    uint64_t slot3 = utf32Buffer[index].unicodeSlot3;
    if (slot3 != 0) {
        hash = (hash * prime + slot3) % 1000000;
    } else { return hash; }
    
    uint64_t slot4 = utf32Buffer[index].unicodeSlot4;
    if (slot4 != 0) {
        hash = (hash * prime + slot4) % 1000000;
    } else { return hash; }
    
    uint64_t slot5 = utf32Buffer[index].unicodeSlot5;
    if (slot5 != 0) {
        hash = (hash * prime + slot5) % 1000000;
    } else { return hash; }
    
    uint64_t slot6 = utf32Buffer[index].unicodeSlot6;
    if (slot6 != 0) {
        hash = (hash * prime + slot6) % 1000000;
    } else { return hash; }
    
    uint64_t slot7 = utf32Buffer[index].unicodeSlot7;
    if (slot7 != 0) {
        hash = (hash * prime + slot7) % 1000000;
    } else { return hash; }
    
    uint64_t slot8 = utf32Buffer[index].unicodeSlot8;
    if (slot8 != 0) {
        hash = (hash * prime + slot8) % 1000000;
    } else { return hash; }
    
    uint64_t slot9 = utf32Buffer[index].unicodeSlot9;
    if (slot9 != 0) {
        hash = (hash * prime + slot9) % 1000000;
    } else { return hash; }
    
    uint64_t slot10 = utf32Buffer[index].unicodeSlot10;
    if (slot10 != 0) {
        hash = (hash * prime + slot10) % 1000000;
    } else { return hash; }
    
    // moar slots
    
    return hash;
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
        setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
        
        const int mySequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
        utf32Buffer[id].totalUnicodeSequenceCount = mySequenceCount;
    }
    
    // If it's an emoji-single, then we just need to set the first 4 bytes, we're done
    else if (category == utf32GlyphEmojiSingle) {
        setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
        
        const int mySequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
        utf32Buffer[id].totalUnicodeSequenceCount = mySequenceCount;
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
            setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
            
            uint32_t nextCodePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            setDataOnSlotAtIndex(utf32Buffer, id, 2, nextCodePoint);
            
            const int mySequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
            const int nextSequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id + mySequenceCount, *utf8BufferSize);
            utf32Buffer[id].totalUnicodeSequenceCount = mySequenceCount + nextSequenceCount;
        }
        
        // If it's a tag, we start doing some special lookahead magic...
        else if (lookaheadCategory == utf32GlyphTag) {
            setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
            const int mySequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
            utf32Buffer[id].totalUnicodeSequenceCount = mySequenceCount;
            
            // Start at the next slot and begin writing for each tag
            int writeSlot = 2;
            int lookaheadSequenceCount = sequenceCountForByteAtIndex(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
            uint32_t codePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            while (lookaheadCategory == utf32GlyphTag && writeSlot <= 10) {
                setDataOnSlotAtIndex(utf32Buffer, id, writeSlot, codePoint);
                utf32Buffer[id].totalUnicodeSequenceCount += lookaheadSequenceCount;
                
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

/* Use a bit of `chopsticks`:
 - If I'm a newline, I just change vertical offsets.
 -- I to the appropriate side and set the vertical offset of the leader.
 - If I'm adjacent to a newline, I'm the line leader or trailer, and I start and stop.
 -- I'm responsible for 'resetting' the horizontal offset as appropriate for a row
 - If I'm not, I get cheeky:
 -- I iterate forward from my index down to my line trailer;
 -- I add my texture size width to the offset of that character, and it will now be included in the total line size;
 -- Eventually I will have my offset incremented by other leading characters, that will be doing the same thing.
*/
kernel void utf32GlyphMapLayout(
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
    if (id < 0 || id >= offsetMax) {
        return;
    }
    
    if (utf32Buffer[id].unicodeHash == 0) {
        return;
    }

    float currentRowStart = 0;
    float currentXOffset = 0;
    float currentYOffset = 0;
    float currentZOffset = 0;
    float currentCharacterOffset = 0;
    float MAX_X_OFFSET = 256;  // because some rectangles are just whacky.
    float MIN_Y_OFFSET = -256; // because some rectangles are just whacky.
    
    bool foundLineStart = false;
    bool shouldContinueBacktrack = true;
    
    uint previousGlyphIndex = id;
    previousGlyphIndex = indexOfCharacterBefore(utf8Buffer,
                                                utf32Buffer,
                                                previousGlyphIndex,
                                                utf8BufferSize);
    while (shouldContinueBacktrack) {
        // Early return; no previous, no previous to read.
        if (previousGlyphIndex == id) {
            shouldContinueBacktrack = false;
            continue;
        }
        
        // --- Do the offset mathing
        GlyphMapKernelOut previousGlyph = utf32Buffer[previousGlyphIndex];
        
        // If we found a new line, add to the current y offset..
        if (previousGlyph.codePoint == 10) {
            currentYOffset -= previousGlyph.textureSize.y;
            foundLineStart = true;
        }
        // And if we're still iterating backward in the same line, accumulate some width
        if (!foundLineStart) {
            currentXOffset += previousGlyph.textureSize.x;
        }
        
        // .. If we're running off max-x, the go back to the leading, drop a line, and move back.
        if (currentXOffset >= MAX_X_OFFSET) {
            currentXOffset = currentRowStart;
            currentZOffset -= 2.0; // Make it a little more visually distinct than a regular /n
        }
        
        // .. We're adding up offset for every previous character, but we need to move ourselves.
        // If we're off the bottom, jump back to top and move backward.
        if (currentYOffset <= MIN_Y_OFFSET) {
            currentYOffset = 0;
            currentZOffset -= 24.0;
            
            currentXOffset += 60;
            MAX_X_OFFSET += 50;
        }
        
        currentCharacterOffset += 1;
        // ---
        
        // --- Do the iterator backtracking
        // Grab the current index, and check the last one
        uint currentIndex = previousGlyphIndex;
        previousGlyphIndex = indexOfCharacterBefore(utf8Buffer,
                                                    utf32Buffer,
                                                    previousGlyphIndex,
                                                    utf8BufferSize);
        
        // Stop backtracking if the index we get back as 'before' is us, which means we're done.
        // Also said, you should keep going iff the previous index is not the current index.
        shouldContinueBacktrack = previousGlyphIndex != currentIndex;
        shouldContinueBacktrack = shouldContinueBacktrack
                               && previousGlyphIndex >= 0
                               && previousGlyphIndex <* utf8BufferSize;
    }
    
    // --- Set the final values all safe like because we're the only writer.. lol.
    utf32Buffer[id].positionOffset.x = currentXOffset;
    utf32Buffer[id].positionOffset.y = currentYOffset;
    utf32Buffer[id].positionOffset.z = currentZOffset;
    utf32Buffer[id].modelMatrix = float4x4(1.0) * translationOf(float3(currentXOffset, currentYOffset, currentZOffset));
    utf32Buffer[id].sourceRenderableStringIndex = currentCharacterOffset;
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
    if (id >= *utf8BufferSize) {
        return;
    }
    
    // Determine the number of bytes in the UTF-8 character
    int sequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
    if (sequenceCount < 1 || sequenceCount > 4) {
        // If it has a weird sequence length, it's glyph data, break early
        utf32Buffer[id].graphemeCategory = utf32GlyphData;
        return;
    }
    
    // Grab 4 bytes from the buffer; we're assuming 0 is returned on out-of-bounds.
    uint8_t firstByte  = getByte(utf8Buffer, id + 0, *utf8BufferSize);
    uint8_t secondByte = getByte(utf8Buffer, id + 1, *utf8BufferSize);
    uint8_t thirdByte  = getByte(utf8Buffer, id + 2, *utf8BufferSize);
    uint8_t fourthByte = getByte(utf8Buffer, id + 3, *utf8BufferSize);
    
    uint32_t codePoint = codePointForSequence(firstByte, secondByte, thirdByte, fourthByte, sequenceCount);
    GraphemeCategory category = categoryForGraphemeBytes(firstByte, secondByte, thirdByte, fourthByte);
    
    utf32Buffer[id].graphemeCategory = category;
    utf32Buffer[id].codePoint = codePoint;
    utf32Buffer[id].codePointIndex = id;
    utf32Buffer[id].foreground = simd_float4(1.0, 1.0, 1.0, 1.0);
    utf32Buffer[id].background = simd_float4(0.0, 0.0, 0.0, 0.0);
    
    attemptUnicodeScalarSetLookahead(
       utf8Buffer,
       utf32Buffer,
       id,
       utf8BufferSize,
       category,
       codePoint
     );
    
    utf32Buffer[id].unicodeHash = glyphHashKernel(utf32Buffer, id);
}

// MARK: -- Atlas texture mapping from utf8 -> GlyphMapKernelOut

kernel void processNewUtf32AtlasMapping(
    device       GlyphMapKernelOut* unprocessedGlyphs     [[buffer(0)]],
                 uint id                                  [[thread_position_in_grid]],
    device       GlyphMapKernelOut* cleanGlyphBuffer      [[buffer(1)]],
    constant     uint* unprocessedSize                    [[buffer(2)]],
    constant     uint* cleanOutputSize                    [[buffer(3)]]
) {
    if (id < 0 || id >= *unprocessedSize) {
        return;
    }
    GlyphMapKernelOut glyphCopy = unprocessedGlyphs[id];
    if (glyphCopy.unicodeHash == 0) {
        return;
    }
    
    uint targetBufferIndex = glyphCopy.sourceRenderableStringIndex;
    if (targetBufferIndex < 0 || targetBufferIndex >= *cleanOutputSize) {
        return;
    }
    
    cleanGlyphBuffer[targetBufferIndex] = glyphCopy;
}

void updateAtomicMin(
     device     atomic_float* atomicValue,
     float      newValue
) {
    bool updated = false;
    while (!updated) {
        float oldValue = atomic_load_explicit(atomicValue, memory_order_relaxed);
        
        // Update only if newValue is less than the currently stored value
        if (newValue < oldValue) {
            // Attempt to swap the old value with newValue
            updated = atomic_compare_exchange_weak_explicit(atomicValue, 
                                                            &oldValue,
                                                            newValue,
                                                            memory_order_relaxed,
                                                            memory_order_relaxed);
        } else {
            // The current value is less than or equal to newValue, no update needed
            break;
        }
    }
}

void updateAtomicMax(
     device     atomic_float* atomicValue,
     float      newValue
) {
    bool updated = false;
    while (!updated) {
        float oldValue = atomic_load_explicit(atomicValue, memory_order_relaxed);
        
        // Update only if newValue is greater than than the currently stored value
        if (newValue > oldValue) {
            // Attempt to swap the old value with newValue
            updated = atomic_compare_exchange_weak_explicit(atomicValue,
                                                            &oldValue,
                                                            newValue,
                                                            memory_order_relaxed,
                                                            memory_order_relaxed);
        } else {
            // The current value is greater than or equal to newValue, no update needed
            break;
        }
    }
}

kernel void blitGlyphsIntoConstants(
    device       GlyphMapKernelOut* unprocessedGlyphs     [[buffer(0)]],
                 uint id                                  [[thread_position_in_grid]],
    device       InstancedConstants* targetConstants      [[buffer(1)]],
    constant     uint* unprocessedSize                    [[buffer(2)]],
    constant     uint* expectedCharacterCount             [[buffer(3)]],
    device       atomic_uint* instanceCounter             [[buffer(4)]],
    
    // Bounds... I am not a gpu person...
    // .. I miss being good algorithmically too...
    device       atomic_float* minX                       [[buffer(5)]],
    device       atomic_float* minY                       [[buffer(6)]],
    device       atomic_float* minZ                       [[buffer(7)]],
                                    
    device       atomic_float* maxX                       [[buffer(8)]],
    device       atomic_float* maxY                       [[buffer(9)]],
    device       atomic_float* maxZ                       [[buffer(10)]]
) {
    if (id < 0 || id >= *unprocessedSize) {
        return;
    }
    GlyphMapKernelOut glyphCopy = unprocessedGlyphs[id];
    if (glyphCopy.unicodeHash == 0) {
        return;
    }
    
    uint targetBufferIndex = glyphCopy.sourceRenderableStringIndex;
    if (targetBufferIndex < 0 || targetBufferIndex >= *expectedCharacterCount) {
        return;
    }
    
    uint myID = atomic_fetch_add_explicit(instanceCounter, 1, memory_order_relaxed);
    targetConstants[targetBufferIndex].instanceID = myID;
    targetConstants[targetBufferIndex].bufferIndex = targetBufferIndex;
    targetConstants[targetBufferIndex].addedColor = float4(0.0);
    targetConstants[targetBufferIndex].useParentMatrix = 1;
    
    targetConstants[targetBufferIndex].unicodeHash = glyphCopy.unicodeHash;
    targetConstants[targetBufferIndex].modelMatrix = glyphCopy.modelMatrix;
    targetConstants[targetBufferIndex].textureDescriptorU = glyphCopy.textureDescriptorU;
    targetConstants[targetBufferIndex].textureDescriptorV = glyphCopy.textureDescriptorV;
    targetConstants[targetBufferIndex].textureSize = glyphCopy.textureSize;
    targetConstants[targetBufferIndex].positionOffset = glyphCopy.positionOffset;
    
    updateAtomicMin(minX, 10);
    updateAtomicMin(minY, 13);
    updateAtomicMin(minZ, 31);
//    updateAtomicMin(minX, glyphCopy.positionOffset.x);
//    updateAtomicMin(minY, glyphCopy.positionOffset.y);
//    updateAtomicMin(minZ, glyphCopy.positionOffset.z);
//    
//    updateAtomicMax(maxX, glyphCopy.positionOffset.x);
//    updateAtomicMax(maxY, glyphCopy.positionOffset.y);
//    updateAtomicMax(maxZ, glyphCopy.positionOffset.z);
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
    if (id >= *utf8BufferSize) {
        return;
    }
    
    // Determine the number of bytes in the UTF-8 character
    int sequenceCount = sequenceCountForByteAtIndex(utf8Buffer, id, *utf8BufferSize);
    if (sequenceCount < 1 || sequenceCount > 4) {
        // If it has a weird sequence length, it's glyph data, break early
        utf32Buffer[id].graphemeCategory = utf32GlyphData;
        return;
    }
    
    // Grab 4 bytes from the buffer; we're assuming 0 is returned on out-of-bounds.
    uint8_t firstByte  = getByte(utf8Buffer, id + 0, *utf8BufferSize);
    uint8_t secondByte = getByte(utf8Buffer, id + 1, *utf8BufferSize);
    uint8_t thirdByte  = getByte(utf8Buffer, id + 2, *utf8BufferSize);
    uint8_t fourthByte = getByte(utf8Buffer, id + 3, *utf8BufferSize);
    
    uint32_t codePoint = codePointForSequence(firstByte, secondByte, thirdByte, fourthByte, sequenceCount);
    GraphemeCategory category = categoryForGraphemeBytes(firstByte, secondByte, thirdByte, fourthByte);
    
    utf32Buffer[id].graphemeCategory = category;
    utf32Buffer[id].codePoint = codePoint;
    utf32Buffer[id].codePointIndex = id;
    utf32Buffer[id].foreground = simd_float4(1.0, 1.0, 1.0, 1.0);
    utf32Buffer[id].background = simd_float4(0.0, 0.0, 0.0, 0.0);
    
    attemptUnicodeScalarSetLookahead(
       utf8Buffer,
       utf32Buffer,
       id,
       utf8BufferSize,
       category,
       codePoint
     );
    
    uint64_t hash = glyphHashKernel(utf32Buffer, id);
    utf32Buffer[id].unicodeHash = hash;
    
    if (hash > 0 && hash < *atlasBufferSize) {
        GlyphMapKernelAtlasIn atlasData = atlasBuffer[hash];
        
        utf32Buffer[id].textureSize = unitSize(atlasData.textureSize);
        utf32Buffer[id].textureDescriptorU = atlasData.textureDescriptorU;
        utf32Buffer[id].textureDescriptorV = atlasData.textureDescriptorV;
        
        /* MARK: Buffer compressomaticleanerating [Pass 1]
         Set the buffer index we started at. Set the original source index, to track both states. lolmemorywhat
        */
        utf32Buffer[id].sourceUtf8BufferIndex = id;
        utf32Buffer[id].unicodeCodePointLength = getUnicodeLengthFromSlots(utf32Buffer, id);
        
        utf32Buffer[id].sourceRenderableStringIndex = id;
        atomic_fetch_add_explicit(totalCharacterCount, 1, memory_order_relaxed);
    }
}
