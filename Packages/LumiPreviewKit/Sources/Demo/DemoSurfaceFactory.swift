import Foundation
import IOSurface
import SuperLogKit
import os

public extension LumiPreviewFacade {
    /// 仅用于 Phase 1 的本地 IOSurface 生成器。
    final class DemoSurfaceFactory: @unchecked Sendable, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiPreviewKit.DemoSurfaceFactory")
        public nonisolated static let emoji = "🎬"
        public nonisolated static let verbose: Bool = false

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
            if LumiPreviewFacade.verbose {
                Self.logger.info("\(self.t)🎬 渲染 Demo 帧：\(width)×\(height) @\(String(format: "%.1f", scale)) seq=\(seq)")
            }
            guard width > 0, height > 0 else {
                if LumiPreviewFacade.verbose {
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
                // 跨进程共享：消费端通过 IOSurfaceLookup(surfaceID) 按 ID 取回 surface，
                // 这要求 surface 必须是 global。kIOSurfaceIsGlobal 被标记为 deprecated
                //（"Global surfaces are insecure"），但当前架构依赖 ID 跨进程序列化，
                // 故此处有意保留该用法。迁移到 mach port 传递可彻底消除该警告。
                kIOSurfaceIsGlobal: true
            ]

            guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
                if LumiPreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ IOSurfaceCreate 返回 nil：\(width)×\(height)")
                }
                return nil
            }

            let surfaceID = IOSurfaceGetID(surface)
            if LumiPreviewFacade.verbose {
                Self.logger.info("\(self.t)✅ 已创建 IOSurface：id=\(surfaceID) \(width)×\(height)")
            }

            paintRedDirectly(into: surface)
            retainSurface(surface)

            if LumiPreviewFacade.verbose {
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
            Self.logger.info("\(self.t)📝[paintRedDirectly] 开始写入 IOSurface")
            
            var seed: UInt32 = 0
            let lockResult = IOSurfaceLock(surface, [], &seed)
            guard lockResult == KERN_SUCCESS else {
                if LumiPreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ IOSurfaceLock 失败：\(lockResult)")
                }
                Self.logger.error("\(self.t)📝[paintRedDirectly] ❌ IOSurfaceLock 失败：\(lockResult)")
                return
            }
            defer { _ = IOSurfaceUnlock(surface, [], &seed) }

            let width = Int(IOSurfaceGetWidth(surface))
            let height = Int(IOSurfaceGetHeight(surface))
            let bytesPerRow = Int(IOSurfaceGetBytesPerRowOfPlane(surface, 0))
            
            // 🔍 诊断：IOSurface 属性
            Self.logger.info("\(self.t)📝[paintRedDirectly] IOSurface 属性：\(width)×\(height), bytesPerRow=\(bytesPerRow)")
            
            let baseAddress = IOSurfaceGetBaseAddressOfPlane(surface, 0)
            Self.logger.info("\(self.t)📝[paintRedDirectly] ✅ baseAddress 非nil")
            
            // 填充红色 (BGRA: B=0, G=0, R=255, A=255)
            // 这样可以看到明显的红色，证明 IOSurface 链路是通的
            let buffer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
            
            // 🔍 诊断：开始填充像素
            Self.logger.info("\(self.t)📝[paintRedDirectly] 开始填充像素：上半红，下半绿")
            
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
            
            if LumiPreviewFacade.verbose {
                Self.logger.info("\(self.t)🎨 已直接写入内存：红/绿各半")
            }
            
            // 🔍 诊断：填充完成
            Self.logger.info("\(self.t)📝[paintRedDirectly] ✅ 像素填充完成")
        }

    }
}
