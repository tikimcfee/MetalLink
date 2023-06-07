
import Foundation
import MetalKit

public class MetalLinkRenderer : NSObject, MTKViewDelegate, MetalLinkReader {
    public let link: MetalLink

    public init(link: MetalLink) throws {
        self.link = link
        super.init()
        link.view.delegate = self
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        link.onSizeChange(view, drawableSizeWillChange: size)
    }
    
    public func draw(in view: MTKView) {
        guard var sdp = SafeDrawPass.wrap(link)
        else {
            print("Cannot create SafeDrawPass")
            return
        }
        
        // TODO: - To encode to the draw pass, add a receiver for the renderer (receivers?)
//        twoETutorial.delegatedEncode(in: &sdp)
        
        // Produce drawable from current render state post-encoding
        sdp.renderCommandEncoder.endEncoding()
        guard let drawable = view.currentDrawable
        else { return }
        
        sdp.commandBuffer.present(drawable)
        sdp.commandBuffer.commit()
    }
}
