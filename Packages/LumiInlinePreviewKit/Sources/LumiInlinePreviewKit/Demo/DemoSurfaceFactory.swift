import CoreGraphics
import Foundation
import IOSurface
import os

public extension LumiInlinePreviewFacade {
    /// 仅用于 Phase 1 的本地 IOSurface 生成器。
    ///
    /// 不依赖任何子进程，纯粹在主进程内画一张测试图，证明
    /// `PreviewSurfaceView` → `CALayer.contents` → `IOSurfaceLookup` 的链路通了。
    /// Phase 2 子进程帧流接入后，此类会被替换。
    final class DemoSurfaceFactory: @unchecked Sendable {

        // MARK: - 单例

        public static let shared = DemoSurfaceFactory()

        // MARK: - 私有

        private let lock = NSLock()
        private var retainPool: [IOSurfaceRef] = []
        private let retainPoolLimit = 8

        private static let bgraPixelFormat: UInt32 =
            UInt32(UInt8(ascii: "B")) << 24 |
            UInt32(UInt8(ascii: "G")) << 16 |
            UInt32(UInt8(ascii: "R")) << 8 |
            UInt32(UInt8(ascii: "A"))

        private init() {}

        // MARK: - 公开方法

        /// 在当前进程中创建一个像素尺寸为 `width × height` 的 BGRA `IOSurface`，
        /// 内容是渐变 + 帧序号方块，方便肉眼校验帧是否更新。
        ///
        /// Factory 内部维护一个最多保留 `retainPoolLimit` 帧的强引用池，
        /// 保证 `IOSurfaceID` 在被消费前不会被 ARC 回收（行为与子进程
        /// 的 `recentSurfaces` 缓冲一致）。
        public func makeFrame(
            width: Int,
            height: Int,
            scale: Double = 2,
            seq: UInt64
        ) -> IOSurfaceFrame? {
            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[DemoSurfaceFactory] makeFrame \(width)×\(height) @\(String(format: "%.1f", scale)) seq=\(seq)")
            }
            guard width > 0, height > 0 else {
                if LumiInlinePreviewFacade.verbose {
                                    LumiInlinePreviewFacade.logger.error("[DemoSurfaceFactory] ❌ invalid dimensions: \(width)×\(height)")
                }
                return nil
            }
            let bytesPerRow = width * 4

            let properties: [CFString: Any] = [
                kIOSurfaceWidth: width,
                kIOSurfaceHeight: height,
                kIOSurfaceBytesPerElement: 4,
                kIOSurfaceBytesPerRow: bytesPerRow,
                kIOSurfacePixelFormat: Self.bgraPixelFormat,
                kIOSurfaceIsGlobal: true
            ]

            guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
                if LumiInlinePreviewFacade.verbose {
                                    LumiInlinePreviewFacade.logger.error("[DemoSurfaceFactory] ❌ IOSurfaceCreate returned nil for \(width)×\(height)")
                }
                return nil
            }

            let surfaceID = IOSurfaceGetID(surface)
            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[DemoSurfaceFactory] ✅ IOSurface created: id=\(surfaceID) \(width)×\(height)")
            }

            paint(into: surface, width: width, height: height, bytesPerRow: bytesPerRow, seq: seq)
            retainSurface(surface)

            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[DemoSurfaceFactory] ✅ Frame ready: surfaceID=\(UInt32(surfaceID)) seq=\(seq)")
            }
            return IOSurfaceFrame(
                surfaceID: UInt32(surfaceID),
                width: width,
                height: height,
                scale: scale,
                seq: seq
            )
        }

        // MARK: - 静态便捷入口

        /// 便捷调用，等价于 `DemoSurfaceFactory.shared.makeFrame(...)`。
        public static func makeFrame(
            width: Int,
            height: Int,
            scale: Double = 2,
            seq: UInt64
        ) -> IOSurfaceFrame? {
            shared.makeFrame(width: width, height: height, scale: scale, seq: seq)
        }

        // MARK: - 私有方法

        private func retainSurface(_ surface: IOSurfaceRef) {
            lock.lock()
            defer { lock.unlock() }
            retainPool.append(surface)
            if retainPool.count > retainPoolLimit {
                retainPool.removeFirst(retainPool.count - retainPoolLimit)
            }
        }

        // MARK: - 私有绘制

        private func paint(
            into surface: IOSurfaceRef,
            width: Int,
            height: Int,
            bytesPerRow: Int,
            seq: UInt64
        ) {
            var seed: UInt32 = 0
            let lockResult = IOSurfaceLock(surface, [], &seed)
            guard lockResult == KERN_SUCCESS else {
                if LumiInlinePreviewFacade.verbose {
                                    LumiInlinePreviewFacade.logger.error("[DemoSurfaceFactory] ❌ IOSurfaceLock failed: \(lockResult)")
                }
                return
            }
            defer { _ = IOSurfaceUnlock(surface, [], &seed) }

            guard let baseAddress = IOSurfaceGetBaseAddressOfPlane(surface, 0) as UnsafeMutableRawPointer?,
                  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                  ) else {
                if LumiInlinePreviewFacade.verbose {
                                    LumiInlinePreviewFacade.logger.error("[DemoSurfaceFactory] ❌ CGContext creation failed")
                }
                return
            }

            let phase = Double(seq % 360) / 360.0
            let bg = CGColor(srgbRed: 0.10 + 0.4 * phase, green: 0.10, blue: 0.30 + 0.5 * (1 - phase), alpha: 1)
            context.setFillColor(bg)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let stripeColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18)
            context.setFillColor(stripeColor)
            let stripeCount = 12
            for i in 0..<stripeCount where (i + Int(seq)) % 2 == 0 {
                let stripeWidth = CGFloat(width) / CGFloat(stripeCount)
                context.fill(CGRect(
                    x: CGFloat(i) * stripeWidth,
                    y: 0,
                    width: stripeWidth,
                    height: CGFloat(height)
                ))
            }

            // 中央方块：帧序号可视化（简单的方块格栅，避免引入字体/文字栈）
            let cellSize = CGFloat(min(width, height)) / 16
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
            for bit in 0..<8 {
                let on = (seq >> bit) & 1 == 1
                guard on else { continue }
                context.fill(CGRect(
                    x: CGFloat(width) / 2 - cellSize * 4 + cellSize * CGFloat(bit),
                    y: CGFloat(height) / 2 - cellSize / 2,
                    width: cellSize - 2,
                    height: cellSize
                ))
            }

            context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6))
            context.setLineWidth(2)
            context.stroke(CGRect(x: 1, y: 1, width: CGFloat(width) - 2, height: CGFloat(height) - 2))

            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[DemoSurfaceFactory] 🎨 Painted seq=\(seq): phase=\(String(format: "%.2f", phase))")
            }
        }
    }
}
