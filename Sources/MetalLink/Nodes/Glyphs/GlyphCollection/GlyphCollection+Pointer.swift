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
        let pointer = Pointer()
        var pointerOffset = LFloat3.zero
        let targetCollection: GlyphCollection
        var lineCount = 0
        var charactersInLines = 0
        private var currentPosition: LFloat3 { pointer.position }
        
        init(collection: GlyphCollection) {
            self.targetCollection = collection
        }
        
        public func insert(
            _ letterNode: MetalLinkGlyphNode
        ) {
            let size = letterNode.quadSize
            
            // Well it turns out I played myself.
            // The inout here overwrote the cached value in the node..
            // because value objects yo.
            letterNode.position = currentPosition
            letterNode.rebuildNow()
            
            pointer.right(size.x)
            charactersInLines += 1
            
            struct Config {
                static let maxCharactersInLine: Int = 120
                static let fileOffsetMinimum: Float = -300
            }
            
            if letterNode.key.source.isNewline {
                newLine(size)
                
                // lol 3d yo, if you have too many lines, we push you somewhere else
                if pointer.position.y <= Config.fileOffsetMinimum {
                    pointerOffset.x += Config.maxCharactersInLine.float
                    pointer.position.x = pointerOffset.x
                    pointer.position.y = 0
                }
            }

            // Break on really long run-on lines
            if charactersInLines >= Config.maxCharactersInLine {
                newLine(size)
            }
        }
        
        public func newLine(_ size: LFloat2) {
            pointer.down(size.y)
            pointer.position.x = pointerOffset.x
            
            lineCount += 1
            charactersInLines = 0
        }
    }
}


