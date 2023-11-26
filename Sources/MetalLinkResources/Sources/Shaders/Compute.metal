#include <metal_stdlib>

#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

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
// start/middle/middle/end == emoji;
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
    
    if (
        byteStatus1 == START
     && byteStatus2 == MIDDLE
     && byteStatus3 == MIDDLE
     && byteStatus4 == END
    ) {
        return utf32GlyphEmojiPrefix;
    }
    else if (
        byteStatus1 == START
     && byteStatus2 == END
     && byteStatus3 == MIDDLE
     && byteStatus4 == END
    ) {
        return utf32GlyphTag;
    }
    else if (
        byteStatus1 == START
     && byteStatus2 == MIDDLE
     && byteStatus3 == END
     && byteStatus4 == END
    ) {
        return utf32GlyphEmojiSingle;
    }
    
    return utf32GlyphSingle;
}

void setBytesOnSlotAtIndex(
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
                int slotNumber,
                uint8_t firstByte,
                uint8_t secondByte,
                uint8_t thirdByte,
                uint8_t fourthByte
) {
    switch (slotNumber) {
        case 1:
            utf32Buffer[id].unicodeSlot1[0] = firstByte;
            utf32Buffer[id].unicodeSlot1[1] = secondByte;
            utf32Buffer[id].unicodeSlot1[2] = thirdByte;
            utf32Buffer[id].unicodeSlot1[3] = fourthByte;
            break;
        case 2:
            utf32Buffer[id].unicodeSlot2[0] = firstByte;
            utf32Buffer[id].unicodeSlot2[1] = secondByte;
            utf32Buffer[id].unicodeSlot2[2] = thirdByte;
            utf32Buffer[id].unicodeSlot2[3] = fourthByte;
            break;
        case 3:
            utf32Buffer[id].unicodeSlot3[0] = firstByte;
            utf32Buffer[id].unicodeSlot3[1] = secondByte;
            utf32Buffer[id].unicodeSlot3[2] = thirdByte;
            utf32Buffer[id].unicodeSlot3[3] = fourthByte;
            break;
        case 4:
            utf32Buffer[id].unicodeSlot4[0] = firstByte;
            utf32Buffer[id].unicodeSlot4[1] = secondByte;
            utf32Buffer[id].unicodeSlot4[2] = thirdByte;
            utf32Buffer[id].unicodeSlot4[3] = fourthByte;
            break;
        case 5:
            utf32Buffer[id].unicodeSlot5[0] = firstByte;
            utf32Buffer[id].unicodeSlot5[1] = secondByte;
            utf32Buffer[id].unicodeSlot5[2] = thirdByte;
            utf32Buffer[id].unicodeSlot5[3] = fourthByte;
            break;
        case 6:
            utf32Buffer[id].unicodeSlot6[0] = firstByte;
            utf32Buffer[id].unicodeSlot6[1] = secondByte;
            utf32Buffer[id].unicodeSlot6[2] = thirdByte;
            utf32Buffer[id].unicodeSlot6[3] = fourthByte;
            break;
        case 7:
            utf32Buffer[id].unicodeSlot7[0] = firstByte;
            utf32Buffer[id].unicodeSlot7[1] = secondByte;
            utf32Buffer[id].unicodeSlot7[2] = thirdByte;
            utf32Buffer[id].unicodeSlot7[3] = fourthByte;
            break;
    }

}

void attemptUnicodeScalarSetLookahead(
   const device uint8_t* utf8Buffer,
   device       GlyphMapKernelOut* utf32Buffer,
                uint id,
   constant     uint* utf8BufferSize,
                GraphemeCategory category,
                uint8_t byte1,
                uint8_t byte2,
                uint8_t byte3,
                uint8_t byte4
) {
    // Data and single-byte glyphs just return their initial bytes;
    // this particular lookahead is done.
    if (category == utf32GlyphSingle || category == utf32GlyphData) {
        setBytesOnSlotAtIndex(utf32Buffer, id, 1, byte1, 0, 0, 0);
    }
    
    // If it's an emoji-single, then we just need to set the first 4 bytes, we're done
    else if (category == utf32GlyphEmojiSingle) {
        setBytesOnSlotAtIndex(utf32Buffer, id, 1, byte1, byte2, byte3, byte4);
    }
    
    // If it's a prefix, we do some work
    else if (category == utf32GlyphEmojiPrefix) {
        setBytesOnSlotAtIndex(utf32Buffer, id, 1, byte1, byte2, byte3, byte4);
        
        uint lookaheadStartIndex = id + 4;
        // Grab lookahead data
        uint8_t lookahead1 = getByte(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
        uint8_t lookahead2 = getByte(utf8Buffer, lookaheadStartIndex + 1, *utf8BufferSize);
        uint8_t lookahead3 = getByte(utf8Buffer, lookaheadStartIndex + 2, *utf8BufferSize);
        uint8_t lookahead4 = getByte(utf8Buffer, lookaheadStartIndex + 3, *utf8BufferSize);
        
        // Grab the category of the next unicode group
        GraphemeCategory lookaheadCategory = categoryForGraphemeBytes(lookahead1, lookahead2, lookahead3, lookahead4);
        
        // We assume that if we have two sequential 'prefix', it's actually one emoji, so set the second slot
        if (lookaheadCategory == utf32GlyphEmojiPrefix) {
            setBytesOnSlotAtIndex(utf32Buffer, id, 2, lookahead1, lookahead2, lookahead3, lookahead4);
        }
        
        // If it's a tag, we start doing some special lookahead magic...
        if (lookaheadCategory == utf32GlyphTag) {
            int writeSlot = 2;
            while (lookaheadCategory == utf32GlyphTag && writeSlot <= 7) {
                setBytesOnSlotAtIndex(utf32Buffer, id, writeSlot, lookahead1, lookahead2, lookahead3, lookahead4);
                
                writeSlot += 1;
                lookaheadStartIndex += 4;
                
                lookahead1 = getByte(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
                lookahead2 = getByte(utf8Buffer, lookaheadStartIndex + 1, *utf8BufferSize);
                lookahead3 = getByte(utf8Buffer, lookaheadStartIndex + 2, *utf8BufferSize);
                lookahead4 = getByte(utf8Buffer, lookaheadStartIndex + 3, *utf8BufferSize);
                
                lookaheadCategory = categoryForGraphemeBytes(lookahead1, lookahead2, lookahead3, lookahead4);
            }
        }
        
        // Otherwise, just return, we don't want to set any other data.
    }
}

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
    
    uint32_t codePoint = 0;
    switch (sequenceCount) {
        case 1:
            codePoint = firstByte;
            break;
        case 2:
            codePoint = decodeByteSequence_2(firstByte, secondByte);
            break;
        case 3:
            codePoint = decodeByteSequence_3(firstByte, secondByte, thirdByte);
            break;
        case 4:
            codePoint = decodeByteSequence_4(firstByte, secondByte, thirdByte, fourthByte);
            break;
    }
    
    GraphemeCategory category = categoryForGraphemeBytes(firstByte, secondByte, thirdByte, fourthByte);
    utf32Buffer[id].graphemeCategory = category;
    
    utf32Buffer[id].sourceValue = codePoint;
    utf32Buffer[id].sourceValueIndex = id;
    utf32Buffer[id].foreground = simd_float4(1.0, 1.0, 1.0, 1.0);
    utf32Buffer[id].background = simd_float4(0.0, 0.0, 0.0, 0.0);
    utf32Buffer[id].textureDescriptorU = simd_float4(0.1, 0.2, 0.3, 0.4);
    utf32Buffer[id].textureDescriptorV = simd_float4(0.1, 0.2, 0.3, 0.4);
    
    attemptUnicodeScalarSetLookahead(
       utf8Buffer,
       utf32Buffer,
       id,
       utf8BufferSize,
       category,
       firstByte,
       secondByte,
       thirdByte,
       fourthByte
     );
}

