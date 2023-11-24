#include <metal_stdlib>
//using namespace metal;

#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

kernel void characterMappingKernel(
   const device uint8_t*  inBuffer  [[buffer(0)]],
         device uint8_t*  outBuffer [[buffer(1)]],
                uint      id        [[thread_position_in_grid]]
) {
    // Perform your mapping operation here
    // For simplicity, we are just copying the input to the output
    outBuffer[id] = inBuffer[id];
}

kernel void utf8CharacterProcessingKernel(
    const device uint8_t* inBuffer [[buffer(0)]],
          device uint8_t* outBuffer [[buffer(1)]],
                 uint id [[thread_position_in_grid]]
) {
    uint8_t byte = inBuffer[id];

    // Check the leading bits to determine if it's a standalone character
    // or part of a multi-byte character
    if ((byte & 0x80) == 0x00) {
        // 1-byte character
    } else if ((byte & 0xE0) == 0xC0) {
        // Start of a 2-byte character
    } else if ((byte & 0xF0) == 0xE0) {
        // Start of a 3-byte character
    } else if ((byte & 0xF8) == 0xF0) {
        // Start of a 4-byte character
    } else {
        // Continuation byte
    }

    // Based on this, perform your desired operation
    // For example, mark character boundaries, count characters, etc.
}

kernel void utf8ToUtf32Kernel(
    const device uint8_t*            utf8Buffer      [[buffer(0)]],
          device GlyphMapKernelOut*  utf32Buffer     [[buffer(1)]],
                 uint                id              [[thread_position_in_grid]],
        constant uint*               utf8BufferSize  [[buffer(2)]])
{
    if (id >= *utf8BufferSize) return; // Boundary check

    uint32_t codePoint = 0;
    uint8_t firstByte = utf8Buffer[id];

    // Determine the number of bytes in the UTF-8 character
    if ((firstByte & 0x80) == 0x00) { // 1-byte sequence
        codePoint = firstByte;
    } else if ((firstByte & 0xE0) == 0xC0) { // 2-byte sequence
        if (id + 1 < *utf8BufferSize) {
            codePoint = ((firstByte & 0x1F) << 6) | (utf8Buffer[id + 1] & 0x3F);
        }
    } else if ((firstByte & 0xF0) == 0xE0) { // 3-byte sequence
        if (id + 2 < *utf8BufferSize) {
            codePoint = ((firstByte & 0x0F) << 12) | ((utf8Buffer[id + 1] & 0x3F) << 6) | (utf8Buffer[id + 2] & 0x3F);
        }
    } else if ((firstByte & 0xF8) == 0xF0) { // 4-byte sequence
        if (id + 3 < *utf8BufferSize) {
            codePoint = ((firstByte & 0x07) << 18) | ((utf8Buffer[id + 1] & 0x3F) << 12) | ((utf8Buffer[id + 2] & 0x3F) << 6) | (utf8Buffer[id + 3] & 0x3F);
        }
    }
    
    // Only write to the buffer if it's the start of a UTF-8 character
    if ((firstByte & 0x80) == 0x00 ||
        (firstByte & 0xE0) == 0xC0 ||
        (firstByte & 0xF0) == 0xE0 ||
        (firstByte & 0xF8) == 0xF0) {
        utf32Buffer[id].sourceValue = codePoint;
        utf32Buffer[id].foreground = simd_float4(1.0, 1.0, 1.0, 1.0);
        utf32Buffer[id].background = simd_float4(0.0, 0.0, 0.0, 0.0);
        utf32Buffer[id].textureDescriptorU = simd_float4(0.1, 0.2, 0.3, 0.4);
        utf32Buffer[id].textureDescriptorV = simd_float4(0.1, 0.2, 0.3, 0.4);
    }
}
