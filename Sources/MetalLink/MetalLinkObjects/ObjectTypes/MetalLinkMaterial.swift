//
//  MetalLinkMaterial.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/9/22.
//

import Foundation
import simd

// TODO: Move this to bridging header
public struct MetalLinkMaterial: MemoryLayoutSizable {
//    var color = LFloat4(0.03, 0.33, 0.22, 1.0)
    var color = LFloat4(0.0, 0.0, 0.0, 1.0)
    
    // Flag that currently implies:
    // Hey, we didn't actually set the color yet. Don't show it. Or whatever.
    var useMaterialColor = false
}

extension MetalLinkMaterial: Equatable { }

