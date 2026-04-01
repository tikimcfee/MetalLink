
import Foundation
import MetalKit

public protocol MetalLinkRendererDelegate {
    func performDelegatedEncode(with pass: SafeDrawPass)
}

#if os(visionOS)
public class MetalLinkRenderer : NSObject, MetalLinkReader {
    public var link: MetalLink
    public var paused = false
    
    public init(link: MetalLink) {
        self.link = link
    }
}
#endif

#if !os(visionOS)
public class MetalLinkRenderer: NSObject, MTKViewDelegate, MetalLinkReader {
    public let link: MetalLink
    public var renderDelegate: MetalLinkRendererDelegate?
    public var paused = false

    /// Optional reference to the new group transform system.
    /// When set, the renderer swaps double buffers at frame start and
    /// provides the current read buffer to each SafeDrawPass.
    /// When nil (backward compat), SafeDrawPass uses the fallback identity buffer.
    public var groupTransformManager: GroupTransformManager?

    public init(link: MetalLink) throws {
        self.link = link
        super.init()
        link.view.delegate = self
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        link.onSizeChange(view, drawableSizeWillChange: size)
    }

    public func draw(in view: MTKView) {
        if paused { return }

        // Swap group transform double buffers at frame start so the GPU
        // reads last frame's data while the CPU can write to the new buffer.
        groupTransformManager?.swapBuffers()

        guard let sdp = SafeDrawPass.wrap(link)
        else {
            print("Cannot create SafeDrawPass")
            return
        }

        // Override the fallback buffer with the real group transform buffer
        // when the manager is available.
        if let readBuffer = groupTransformManager?.currentReadBuffer {
            sdp.groupTransformBuffer = readBuffer
        }

        renderDelegate?.performDelegatedEncode(with: sdp)

        // Produce drawable from current render state post-encoding
        sdp.renderCommandEncoder.endEncoding()
        guard let drawable = view.currentDrawable
        else { return }

        sdp.commandBuffer.present(drawable)
        sdp.commandBuffer.commit()
    }
}
#endif
