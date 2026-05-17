import CoreGraphics
import Foundation
import IOSurface
import MagicKit
import os

public extension LumiInlinePreviewFacade {
    /// 仅用于 Phase 1 的本地 IOSurface 生成器。
    final class DemoSurfaceFactory: @unchecked Sendable, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiInlinePreviewKit.DemoSurfaceFactory")
        public nonisolated static let emoji = "🎬"
        public nonisolated static let verbose: Bool = true

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

        public func makeFrame(
            width: Int,
            height: Int,
            scale: Double = 2,
            seq: UInt64
        ) -> IOSurfaceFrame? {
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)🎬 渲染 Demo 帧：\(width)×\(height) @\(String(format: "%.1f", scale)) seq=\(seq)")
            }
            guard width > 0, height > 0 else {
                if LumiInlinePreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ 无效尺寸：\(width)×\(height)")
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
                    Self.logger.error("\(self.t)❌ IOSurfaceCreate 返回 nil：\(width)×\(height)")
                }
                return nil
            }

            let surfaceID = IOSurfaceGetID(surface)
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)✅ 已创建 IOSurface：id=\(surfaceID) \(width)×\(height)")
            }

            // 🔴 验证模式：直接写入红色内存，跳过 CGContext
            paintRedDirectly(into: surface)
            
            // paint(into: surface, width: width, height: height, bytesPerRow: bytesPerRow, seq: seq)
            retainSurface(surface)

            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)✅ 帧已就绪：surfaceID=\(UInt32(surfaceID)) seq=\(seq)")
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

        // 🔴 验证：直接写入内存
        private func paintRedDirectly(into surface: IOSurfaceRef) {
            // 🔍 诊断：记录 paintRedDirectly 开始
            Self.logger.info("📝[paintRedDirectly] 开始写入 IOSurface")
            
            var seed: UInt32 = 0
            let lockResult = IOSurfaceLock(surface, [], &seed)
            guard lockResult == KERN_SUCCESS else {
                if LumiInlinePreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ IOSurfaceLock 失败：\(lockResult)")
                }
                Self.logger.error("📝[paintRedDirectly] ❌ IOSurfaceLock 失败：\(lockResult)")
                return
            }
            defer { _ = IOSurfaceUnlock(surface, [], &seed) }

            let width = Int(IOSurfaceGetWidth(surface))
            let height = Int(IOSurfaceGetHeight(surface))
            let bytesPerRow = Int(IOSurfaceGetBytesPerRowOfPlane(surface, 0))
            
            // 🔍 诊断：IOSurface 属性
            Self.logger.info("📝[paintRedDirectly] IOSurface 属性：\(width)×\(height), bytesPerRow=\(bytesPerRow)")
            
            // IOSurfaceGetBaseAddressOfPlane 返回非 Optional 指针（或 IUO），直接赋值
            let baseAddress = IOSurfaceGetBaseAddressOfPlane(surface, 0)
            
            // 🔍 诊断：检查 baseAddress
            if baseAddress == nil {
                Self.logger.error("📝[paintRedDirectly] ❌ baseAddress 为 nil")
                return
            }
            Self.logger.info("📝[paintRedDirectly] ✅ baseAddress 非nil")
            
            // 填充红色 (BGRA: B=0, G=0, R=255, A=255)
            // 这样可以看到明显的红色，证明 IOSurface 链路是通的
            let buffer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
            
            // 🔍 诊断：开始填充像素
            Self.logger.info("📝[paintRedDirectly] 开始填充像素：上半红，下半绿")
            
            // 优化：只填充一半高度为红色，一半为绿色，以确认尺寸有效
            for y in 0..<height {
                let rowOffset = y * bytesPerRow
                // 上半部分红色，下半部分绿色
                let r = (y < height / 2) ? UInt8(255) : UInt8(0)
                let g = (y < height / 2) ? UInt8(0) : UInt8(255)
                let b = UInt8(0)
                let a = UInt8(255) // 完全不透明
                
                for x in 0..<width {
                    let offset = rowOffset + x * 4
                    buffer[offset] = b     // B
                    buffer[offset + 1] = g // G
                    buffer[offset + 2] = r // R
                    buffer[offset + 3] = a // A
                }
            }
            
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)🎨 已直接写入内存：红/绿各半")
            }
            
            // 🔍 诊断：填充完成
            Self.logger.info("📝[paintRedDirectly] ✅ 像素填充完成")
        }

        // MARK: - 私有绘制 (暂存)

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
                    Self.logger.error("\(self.t)❌ IOSurfaceLock 失败：\(lockResult)")
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
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                  ) else {
                if LumiInlinePreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ CGContext 创建失败")
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

            // 中央方块
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
                Self.logger.info("\(self.t)🎨 已绘制 seq=\(seq): phase=\(String(format: "%.2f", phase))")
            }
        }
    }
}
