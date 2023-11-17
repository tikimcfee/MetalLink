//
//
//  With thanks and appreciation to the silicon and lightning that cooperated to generate this.
//  Created on 11/16/23.
//

import Foundation

public class BoundingVolumeHierarchyNode {
    var boundingBox: AxisAlignedBoundingBox
    var children: [BoundingVolumeHierarchyNode]
    var parentNode: BoundingVolumeHierarchyNode?
    var metalLinkNode: MetalLinkNode?
    
    init(boundingBox: AxisAlignedBoundingBox, metalLinkNode: MetalLinkNode? = nil) {
        self.boundingBox = boundingBox
        self.metalLinkNode = metalLinkNode
        self.children = []
    }
    
    func insert(_ node: BoundingVolumeHierarchyNode) {
        // Simplified insertion logic for demonstration purposes
        children.append(node)
        node.parentNode = self
        // Update bounding box here if necessary
    }
    
    func remove(_ metalLinkNode: MetalLinkNode) {
        // Simplified removal logic for demonstration purposes
        children.removeAll { $0.metalLinkNode === metalLinkNode }
        // Update bounding box here if necessary
    }
    
    func computeBounds() -> AxisAlignedBoundingBox {
        var computedBounds = boundingBox
        for child in children {
            let childBounds = child.computeBounds()
            computedBounds = computedBounds.union(with: childBounds)
        }
        return computedBounds
    }
    
    // More BoundingVolumeHierarchyNode related methods...
}
