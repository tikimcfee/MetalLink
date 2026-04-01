//
//  GroupTransformManager.swift
//  MetalLink
//
//  Created by Ivan Lugo on 2026-03-31.
//

import Metal
import simd

/// Manages a double-buffered MTLBuffer of per-group transform matrices.
///
/// Each group gets a `simd_float4x4` in GPU memory, indexed by `UInt16` groupId.
/// Group 0 is reserved as identity (no group / unmigrated).
/// The CPU shadow array mirrors GPU state for readback (serialization, hit-test enrichment).
///
/// All access is `@MainActor` -- writes come through `CommandRouter`,
/// reads happen during render encoding. Double-buffering prevents CPU/GPU races:
/// CPU writes to the current write buffer while GPU reads the previous frame's buffer.
@MainActor
public final class GroupTransformManager {

    // MARK: - Constants

    /// Maximum number of groups. UInt16 max is 65535, but 4096 is practical.
    public static let maxGroups: Int = 4096

    /// Stride of one transform entry in bytes (simd_float4x4 = 64 bytes).
    private static let transformStride = MemoryLayout<simd_float4x4>.stride

    // MARK: - State

    private let device: MTLDevice

    /// Double-buffered GPU buffers. Index toggles each frame.
    private var buffers: [MTLBuffer]
    private var currentBufferIndex: Int = 0

    /// CPU shadow for readback without GPU synchronization.
    private var cpuShadow: [simd_float4x4]

    /// Free list for recycled group IDs.
    private var freeIds: [UInt16] = []

    /// Next unallocated group ID. Starts at 1 (0 is reserved).
    private var nextId: UInt16 = 1

    // MARK: - Init

    /// `nonisolated` to allow creation from non-isolated contexts (e.g., static let).
    nonisolated public init(device: MTLDevice) {
        self.device = device

        let bufferLength = Self.transformStride * Self.maxGroups

        self.buffers = (0..<2).map { index in
            guard let buffer = device.makeBuffer(
                length: bufferLength,
                options: .storageModeShared
            ) else {
                fatalError("[GroupTransformManager] Failed to allocate MTLBuffer[\(index)]")
            }
            buffer.label = "GroupTransforms[\(index)]"

            // Initialize all entries to identity
            let pointer = buffer.contents().bindMemory(
                to: simd_float4x4.self,
                capacity: Self.maxGroups
            )
            for i in 0..<Self.maxGroups {
                pointer[i] = matrix_identity_float4x4
            }
            return buffer
        }

        self.cpuShadow = Array(
            repeating: matrix_identity_float4x4,
            count: Self.maxGroups
        )
    }

    // MARK: - Group ID Allocation

    /// Allocates the next available group ID. Recycles from the free list first.
    /// - Returns: A `UInt16` group ID. Never returns 0 (reserved for identity/no group).
    public func allocateGroupId() -> UInt16 {
        if let recycled = freeIds.popLast() {
            return recycled
        }
        guard nextId < UInt16(Self.maxGroups) else {
            fatalError("[GroupTransformManager] Exhausted group IDs (max \(Self.maxGroups))")
        }
        let id = nextId
        nextId += 1
        return id
    }

    /// Returns a group ID to the free list and resets its transform to identity.
    public func recycleGroupId(_ id: UInt16) {
        guard id != 0 else { return } // Never recycle the reserved group
        setTransform(id, matrix_identity_float4x4)
        freeIds.append(id)
    }

    // MARK: - Transform Access

    /// Sets the full 4x4 transform for a group.
    /// Writes to both the CPU shadow and the current GPU write buffer.
    public func setTransform(_ groupId: UInt16, _ transform: simd_float4x4) {
        let index = Int(groupId)
        guard index < Self.maxGroups else { return }

        cpuShadow[index] = transform

        let pointer = currentWriteBuffer.contents().bindMemory(
            to: simd_float4x4.self,
            capacity: Self.maxGroups
        )
        pointer[index] = transform
    }

    /// Convenience: sets a translation-only transform for a group.
    public func setOffset(_ groupId: UInt16, _ offset: SIMD3<Float>) {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(offset.x, offset.y, offset.z, 1)
        setTransform(groupId, transform)
    }

    /// Reads the transform from the CPU shadow (no GPU synchronization needed).
    public func getTransform(_ groupId: UInt16) -> simd_float4x4 {
        let index = Int(groupId)
        guard index < Self.maxGroups else { return matrix_identity_float4x4 }
        return cpuShadow[index]
    }

    // MARK: - Frame Management

    /// Call at frame start before encoding. Swaps the double buffer and copies
    /// the CPU shadow into the new write buffer so it stays coherent.
    public func swapBuffers() {
        currentBufferIndex = (currentBufferIndex + 1) % 2

        // Copy shadow state into the new write buffer
        let pointer = currentWriteBuffer.contents().bindMemory(
            to: simd_float4x4.self,
            capacity: Self.maxGroups
        )
        let count = Int(nextId)
        for i in 0..<count {
            pointer[i] = cpuShadow[i]
        }
    }

    /// The buffer the GPU should read this frame (written last frame).
    public var currentReadBuffer: MTLBuffer {
        buffers[(currentBufferIndex + 1) % 2]
    }

    /// The buffer the CPU writes to this frame.
    private var currentWriteBuffer: MTLBuffer {
        buffers[currentBufferIndex]
    }

    // MARK: - Diagnostics

    /// Number of currently allocated (non-recycled) groups, excluding group 0.
    public var allocatedGroupCount: Int {
        Int(nextId) - 1 - freeIds.count
    }
}
