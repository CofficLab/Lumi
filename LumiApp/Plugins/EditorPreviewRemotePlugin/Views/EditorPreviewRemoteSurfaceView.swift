import AppKit
import CoreImage
import IOSurface
import LumiPreviewKit
import Metal
import QuartzCore
import SwiftUI

struct EditorPreviewRemoteSurfaceView: NSViewRepresentable {
    let surfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame

    func makeNSView(context: Context) -> SurfaceMetalView {
        SurfaceMetalView()
    }

    func updateNSView(_ nsView: SurfaceMetalView, context: Context) {
        nsView.display(surfaceFrame)
    }
}

final class SurfaceMetalView: NSView {
    private let metalLayer = CAMetalLayer()
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext?
    private var lastSurfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame?

    override init(frame frameRect: NSRect) {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.ciContext = device.map { CIContext(mtlDevice: $0) }
        super.init(frame: frameRect)

        wantsLayer = true
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.contentsGravity = .resizeAspect
        layer = metalLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        drawCurrentFrame()
    }

    func display(_ surfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame) {
        lastSurfaceFrame = surfaceFrame
        drawCurrentFrame()
    }

    private func drawCurrentFrame() {
        guard let surfaceFrame = lastSurfaceFrame,
              let resolvedSurface = EditorPreviewRemoteSurfaceResolver.resolve(surfaceFrame),
              let device,
              let commandQueue,
              let ciContext,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return
        }

        let drawableSize = CGSize(width: resolvedSurface.width, height: resolvedSurface.height)
        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
        }
        metalLayer.contentsScale = resolvedSurface.scale

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: resolvedSurface.width,
            height: resolvedSurface.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let inputTexture = device.makeTexture(
            descriptor: descriptor,
            iosurface: resolvedSurface.surface,
            plane: 0
        ),
              let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let image = CIImage(mtlTexture: inputTexture, options: [.colorSpace: colorSpace]) else {
            return
        }

        ciContext.render(
            image,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(x: 0, y: 0, width: resolvedSurface.width, height: resolvedSurface.height),
            colorSpace: colorSpace
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
