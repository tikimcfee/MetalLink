//
//  GlyphCollectionWriter.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 9/14/22.
//

import Foundation
import MetalLinkHeaders

class RopeNode {
    var value: String
    var weight: Int
    var left: RopeNode?
    var right: RopeNode?

    init(value: String) {
        self.value = value
        self.weight = value.count
    }
}

class Rope {
    var root: RopeNode

    init(value: String) {
        self.root = RopeNode(value: value)
    }

    func index(_ i: Int) -> Character? {
        return index(i, node: root)
    }

    private func index(_ i: Int, node: RopeNode?) -> Character? {
        guard let node = node else { return nil }
        let value = node.value
        
        if i < node.weight {
            return i < value.count
                ? value[value.index(value.startIndex, offsetBy: i)]
                : index(i - node.weight, node: node.right)
        } else {
            return index(i - node.weight, node: node.right)
        }
    }

    // Insertion and deletion methods would go here.
}

public actor AsyncCollectionWriter {
    let target: GlyphCollection
    var linkAtlas: MetalLinkAtlas { target.linkAtlas }
    
    public init(target: GlyphCollection) {
        self.target = target
    }
    
    
}

public struct GlyphCollectionWriter {
    private static let locked_worker = DispatchQueue(label: "WriterWritingWritely", qos: .userInteractive)
    
    let target: GlyphCollection
    var linkAtlas: MetalLinkAtlas { target.linkAtlas }
    
    public init(target: GlyphCollection) {
        self.target = target
    }
    
    // TODO: Add a 'render all of this' function to avoid
    // potentially recreating the buffer hundreds of times.
    // Buffer *should* only reset when the texture is called,
    // but that's a fragile guarantee.
    public func addGlyph(
        _ key: GlyphCacheKey
    ) -> GlyphNode? {
        doAddGlyph(key)
    }
    
    private func doAddGlyph(
        _ key: GlyphCacheKey
    ) -> GlyphNode? {
        linkAtlas.addGlyphToAtlasIfMissing(key)
        
        guard let newGlyph = target.generateInstance(key) else {
            print("No glyph for", key)
            return .none
        }
        
        newGlyph.parent = target
        target.instanceState.appendToState(node: newGlyph)
        
        do {
            try target.instanceState.makeAndUpdateConstants { constants in
                if let cachedPair = linkAtlas.uvPairCache[key] {
                    constants.textureDescriptorU = cachedPair.u
                    constants.textureDescriptorV = cachedPair.v
                } else {
                    print("--------------")
                    print("MISSING UV PAIR")
                    print("\(key.glyph)")
                    print("--------------")
                }
                
                target.instanceState.instanceIdNodeLookup[constants.instanceID] = newGlyph
                newGlyph.instanceConstants = constants
                newGlyph.instanceBufferIndex = constants.arrayIndex
                newGlyph.instanceID = constants.instanceID
                target.renderer.insert(newGlyph, &constants)
            }
        } catch {
            print(error)
        }
        
        return newGlyph
    }
}
