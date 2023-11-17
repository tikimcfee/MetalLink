//
//
//  With thanks and appreciation to the silicon and lightning that cooperated to generate this.
//  Created on 11/16/23.
//

public class BoundingVolumeHierarchy {
    private var root: BoundingVolumeHierarchyNode?
    
    public init() {}
    
    public func insert(node: MetalLinkNode) {
//        let nodeBounds = node.computeBoundingBoxInLocalSpace()
//        
//        // TODO: THIS DOES NOT COMPILE
//        // The compilation error is: `Cannot convert value of type 'Bounds' to expected argument type 'AxisAlignedBoundingBox'`.
//        // The reason for the error is `MetalLinkNode` and `Measures` need to be updated to use these nodes and this algorithmic implementation.
//        let newNode = BoundingVolumeHierarchyNode(
//            boundingBox: nodeBounds,
//            metalLinkNode: node
//        )
//        
//        if let root = root {
//            root.insert(newNode)
//        } else {
//            root = newNode
//        }
    }
    
    public func remove(node: MetalLinkNode) {
        guard let root = root else { return }
        root.remove(node)
    }
    
    public func update(node: MetalLinkNode) {
        remove(node: node)
        insert(node: node)
    }
    
    public func computeBounds() -> AxisAlignedBoundingBox {
        guard let root = root else {
            fatalError("BVH is empty, cannot compute bounds.")
        }
        return root.computeBounds()
    }
    
}
