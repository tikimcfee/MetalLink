//
//  MeshLibrary.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 8/7/22.
//

import MetalKit
import BitHandling

public enum MeshType {
    case Triangle
    case Quad
}

public class MeshLibrary: LockingCache<MeshType, MetalLinkMesh> {
    let link: MetalLink
    
    init(_ link: MetalLink) {
        self.link = link
    }
    
    public override func make(_ key: Key) -> Value {
        switch key {
        case .Triangle:
            return MetalLinkTriangleMesh(link)
        case .Quad:
            return MetalLinkQuadMesh(link)
        }
    }
}

extension MeshLibrary {
    func makeObject(_ type: MeshType) -> MetalLinkObject {
        MetalLinkObject(link, mesh: self[type])
    }
}
