//
//  GlyphCollection+Pointer.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/21/22.
//

import Metal
import simd
import MetalLinkHeaders

public extension GlyphCollection {
    class Pointer {
        public var position: LFloat3 = .zero
        
        public func right(_ dX: Float) { position.x += dX }
        public func left(_ dX: Float) { position.x -= dX }
        public func up(_ dY: Float) { position.y += dY }
        public func down(_ dY: Float) { position.y -= dY }
        public func away(_ dZ: Float) { position.z -= dZ }
        public func toward(_ dZ: Float) { position.z += dZ }
        
        public func reset() { position = .zero }
    }
    
    class RenderState {
        var lines: [[MetalLinkGlyphNode]] = []
    }
    
    class Renderer {
        struct Config {
            static let newLineSizeRatio: Float = 1.10
        }
        
        let pointer = Pointer()
        var pointerOffset = LFloat3.zero
        let targetCollection: GlyphCollection
        var lineCount = 0
        var charactersInLines = 0
        private var currentPosition: LFloat3 { pointer.position }
        
        init(collection: GlyphCollection) {
            self.targetCollection = collection
        }
        
        func insert(
            _ letterNode: MetalLinkGlyphNode,
            _ constants: inout InstancedConstants
        ) {
            let size = letterNode.quadSize
            
            // *Must set initial model matrix on constants*.
            // Nothing directly updates this in the normal render flow.
            // Give them an initial based on the faux-node's position.
            // TODO: Is this obsoleted with BackingBuffer and node updates?
            letterNode.position = currentPosition
            constants.modelMatrix = matrix_multiply(
                targetCollection.modelMatrix,
                letterNode.modelMatrix
            )
            
            pointer.right(size.x)
            charactersInLines += 1
            
            // Break on really long run-on lines
            
            if letterNode.key.source.isNewline {
                newLine(size)
                
                // lol 3d yo, if you have too many lines, we push you to the Z
                if pointer.position.y <= -300 {
                    pointerOffset.x += 100
//                    pointerOffset.x = 0
                    pointer.position.x = pointerOffset.x
                    pointer.position.y = 0
//                    pointer.position.z -= 32
                }
            }
            
            if charactersInLines >= 220 {
                newLine(size)
            }
        }
        
        func newLine(_ size: LFloat2) {
//            pointer.down(size.y * Config.newLineSizeRatio)
            pointer.down(size.y)
            pointer.position.x = pointerOffset.x
            
            lineCount += 1
            charactersInLines = 0
        }
    }
}


