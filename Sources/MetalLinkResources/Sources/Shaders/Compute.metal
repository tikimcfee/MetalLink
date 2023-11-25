#include <metal_stdlib>
//using namespace metal;

#include "../../../MetalLinkHeaders/Sources/MetalLinkHeaders.h"
#include "MetalLinkShared.metal"

kernel void utf8ToUtf32Kernel(
    const device uint8_t*            utf8Buffer      [[buffer(0)]],
          device GlyphMapKernelOut*  utf32Buffer     [[buffer(1)]],
                 uint                id              [[thread_position_in_grid]],
        constant uint*               utf8BufferSize  [[buffer(2)]])
{
    if (id >= *utf8BufferSize) return; // Boundary check

    uint32_t codePoint = 0;
    
    uint8_t firstByte = utf8Buffer[id];
    
    uint8_t secondByte = 0;
    if (id + 1 < *utf8BufferSize) {
        secondByte = utf8Buffer[id + 1];
    }
    
    uint8_t thirdByte = 0;
    if (id + 2 < *utf8BufferSize) {
        thirdByte = utf8Buffer[id + 2];
    }
    
    uint8_t fourthByte = 0;
    if (id + 3 < *utf8BufferSize) {
        fourthByte = utf8Buffer[id + 3];
    }
    
    // Determine the number of bytes in the UTF-8 character
    if ((firstByte & 0x80) == 0x00) { // 1-byte sequence
        codePoint = firstByte;
    } else if ((firstByte & 0xE0) == 0xC0) { // 2-byte sequence
        codePoint = ((firstByte & 0x1F) << 6)  | (secondByte & 0x3F);
    } else if ((firstByte & 0xF0) == 0xE0) { // 3-byte sequence
        codePoint = ((firstByte & 0x0F) << 12) | ((secondByte & 0x3F) << 6) | (thirdByte & 0x3F);
    } else if ((firstByte & 0xF8) == 0xF0) { // 4-byte sequence
        codePoint = ((firstByte & 0x07) << 18) | ((secondByte & 0x3F) << 12) | ((thirdByte & 0x3F) << 6) | (fourthByte & 0x3F);
    }
    
    // Only write to the buffer if it's the start of a UTF-8 character
    // MARK: NOTE / TAKE CARE / BE AWARE [Buffer size]
    // The ID here is offset by the UTF size 4!
    // Account for this in your buffer!
    //    if (index > 0) {
    //        index = (id + 3) / 4;
    //    }
    //

    uint index = id;
    if ((firstByte & 0x80) == 0x00 ||
        (firstByte & 0xE0) == 0xC0 ||
        (firstByte & 0xF0) == 0xE0 ||
        (firstByte & 0xF8) == 0xF0) {
        utf32Buffer[index].sourceValue = codePoint;
        utf32Buffer[index].foreground = simd_float4(1.0, 1.0, 1.0, 1.0);
        utf32Buffer[index].background = simd_float4(0.0, 0.0, 0.0, 0.0);
        utf32Buffer[index].textureDescriptorU = simd_float4(0.1, 0.2, 0.3, 0.4);
        utf32Buffer[index].textureDescriptorV = simd_float4(0.1, 0.2, 0.3, 0.4);
    }
}
