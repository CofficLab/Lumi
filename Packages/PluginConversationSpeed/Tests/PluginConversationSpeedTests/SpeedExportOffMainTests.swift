import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import PluginConversationSpeed

/// 回归 #1225：指标卡片导出 PNG 时，编码与落盘必须在后台线程完成，
/// 主线程只负责 ImageRenderer 光栅化与保存面板。
@Suite("Speed PNG export off-main")
struct SpeedExportOffMainTests {

    @Test("writePNG 在后台线程编码并写出可解码的 PNG")
    func writesOffMain() async throws {
        let cgImage = try makeCGImage()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speed-export-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let box = ImageBox(cgImage)
        let flag = ThreadFlag()
        try await Task.detached(priority: .userInitiated) {
            try speedEncodeOffMain(box.image, to: url, flag: flag)
        }.value

        #expect(flag.value == false, "PNG 编码/落盘不应发生在主线程")
        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
        let rep = NSBitmapImageRep(data: data)
        #expect(rep != nil, "写出的文件必须是可解码的 PNG")
        #expect(rep?.pixelsWide == 8)
        #expect(rep?.pixelsHigh == 8)
    }

    @Test("目标目录不存在时 writePNG 抛出错误而非静默失败")
    func writeFailureThrows() async throws {
        let cgImage = try makeCGImage()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)/out.png")
        let box = ImageBox(cgImage)

        await #expect(throws: (any Error).self) {
            try await Task.detached(priority: .userInitiated) {
                try SpeedPopover.writePNG(box.image, to: url)
            }.value
        }
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并执行编码。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func speedEncodeOffMain(_ image: CGImage, to url: URL, flag: ThreadFlag) throws {
    flag.value = Thread.isMainThread
    try SpeedPopover.writePNG(image, to: url)
}

private func makeCGImage() throws -> CGImage {
    guard let ctx = CGContext(
        data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw TestImageError.contextCreationFailed
    }
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    guard let image = ctx.makeImage() else {
        throw TestImageError.contextCreationFailed
    }
    return image
}

private enum TestImageError: Error { case contextCreationFailed }

/// CGImage 不可变，可安全跨线程读取；包一层越过 Sendable 检查。
private struct ImageBox: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}