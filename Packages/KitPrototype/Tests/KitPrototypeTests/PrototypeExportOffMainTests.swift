import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KitPrototype

/// 原型屏 PNG 编码必须在后台线程执行（Issue #1193）。
@Suite("Prototype PNG export off-main")
struct PrototypeExportOffMainTests {

    @Test("encodePNG 在后台线程归一化并编码出目标尺寸的 PNG")
    func encodeRunsOffMain() async throws {
        let source = try #require(Self.makeSourceCGImage(size: 16))
        let box = SourceBox(cgImage: source)
        let flag = ThreadFlag()

        let data = try await Task.detached(priority: .userInitiated) {
            try Self.runEncodeOffMain(flag: flag, sourceImage: box.cgImage, width: 8, height: 8)
        }.value

        #expect(flag.value == false, "PNG 归一化与编码必须在非主线程执行")
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == 8)
        #expect(rep.pixelsHigh == 8)
    }

    @Test("非法尺寸导致编码失败时抛出 pngEncodingFailed")
    func encodeFailureThrows() {
        guard let source = Self.makeSourceCGImage(size: 4) else {
            Issue.record("无法构造测试用 CGImage")
            return
        }
        #expect(throws: PrototypeExportError.pngEncodingFailed) {
            _ = try PrototypeHTMLExporter.encodePNG(sourceImage: source, width: 0, height: 0)
        }
    }

    /// 同步辅助函数：记录当前线程并调用生产编码逻辑。
    ///
    /// `Thread.isMainThread` 在 async 上下文不可用，必须放在同步函数里。
    private static func runEncodeOffMain(
        flag: ThreadFlag,
        sourceImage: CGImage,
        width: Int,
        height: Int
    ) throws -> Data {
        flag.value = Thread.isMainThread
        return try PrototypeHTMLExporter.encodePNG(sourceImage: sourceImage, width: width, height: height)
    }

    private static func makeSourceCGImage(size: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }
}

private struct SourceBox: @unchecked Sendable {
    let cgImage: CGImage
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}