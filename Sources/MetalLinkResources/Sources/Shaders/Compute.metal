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
    }
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
    }
    
    // If it's an emoji-single, then we just need to set the first 4 bytes, we're done
    else if (category == utf32GlyphEmojiSingle) {
        setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
    }
    
    // If it's a prefix, we do some work
    else if (category == utf32GlyphEmojiPrefix) {
        // We assume that if we have two sequential 'prefix', it's actually one emoji, so set the second slot
        if (lookaheadCategory == utf32GlyphEmojiPrefix) {
            setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
            
            uint32_t nextCodePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            setDataOnSlotAtIndex(utf32Buffer, id, 2, nextCodePoint);
        }
        
        // If it's a tag, we start doing some special lookahead magic...
        else if (lookaheadCategory == utf32GlyphTag) {
            setDataOnSlotAtIndex(utf32Buffer, id, 1, codePoint);
            
            int writeSlot = 2;
            uint32_t codePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, 4);
            while (lookaheadCategory == utf32GlyphTag && writeSlot <= 7) {
                setDataOnSlotAtIndex(utf32Buffer, id, writeSlot, codePoint);
                
                writeSlot += 1;
                lookaheadStartIndex += 4;
                
                lookahead1 = getByte(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
                lookahead2 = getByte(utf8Buffer, lookaheadStartIndex + 1, *utf8BufferSize);
                lookahead3 = getByte(utf8Buffer, lookaheadStartIndex + 2, *utf8BufferSize);
                lookahead4 = getByte(utf8Buffer, lookaheadStartIndex + 3, *utf8BufferSize);
                
                int sequenceCount = sequenceCountForByteAtIndex(utf8Buffer, lookaheadStartIndex, *utf8BufferSize);
                codePoint = codePointForSequence(lookahead1, lookahead2, lookahead3, lookahead4, sequenceCount);
                
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
    
    uint32_t codePoint = codePointForSequence(firstByte, secondByte, thirdByte, fourthByte, sequenceCount);
    
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
       codePoint
     );
}

