import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import PluginConversationCacheHitRate

/// 回归 #515：缓存命中率卡片「保存为图片」时，落盘失败必须把错误带回 UI（弹窗报错），
/// 不能静默当作正常完成的导出。
///
/// ## 背景
/// 旧实现用 `try? pngData.write(to: url)` 吞掉写入错误，随后直接结束导出态，
/// 用户无法区分「保存成功」与「目标文件根本没更新」。#1225 把编码/落盘移到后台
/// 并改成 `try` 抛错 + catch 写 `exportErrorMessage`（驱动 `.alert`）。
/// `CacheHitRateExportOffMainTests.writeFailureThrows` 只锁住 `writePNG` 会抛错，
/// 本套件进一步锁住「抛出的错误确实被接住并转成可见文案」这半条链路：
/// 若有人把 catch 改回静默（返回 nil），失败用例立即变红。
@Suite("Cache hit rate PNG export error reporting (#515)")
struct CacheHitRateExportErrorReportingTests {

    @Test("落盘失败时带回错误文案，而非静默成功")
    func exportFailureReportsErrorMessage() async throws {
        let cgImage = try makeCGImage()
        // 目标目录不存在 → writePNG 必抛错（权限/路径失败的代表）。
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)/out.png")

        let message = await CacheHitRatePopover.exportPNG(ExportableCGImage(cgImage), to: url)

        #expect(message != nil, "落盘失败必须带回错误文案供弹窗展示，不能返回 nil 假装成功")
        #expect(message?.isEmpty == false, "错误文案不得为空串")
    }

    @Test("成功落盘返回 nil 且写出可解码 PNG")
    func exportSuccessReportsNoError() async throws {
        let cgImage = try makeCGImage()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-export-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let message = await CacheHitRatePopover.exportPNG(ExportableCGImage(cgImage), to: url)

        #expect(message == nil, "成功落盘不应误报错误")
        let data = try Data(contentsOf: url)
        let rep = NSBitmapImageRep(data: data)
        #expect(rep != nil, "写出的文件必须是可解码的 PNG")
        #expect(rep?.pixelsWide == 8)
        #expect(rep?.pixelsHigh == 8)
    }
}

// MARK: - Helpers

private func makeCGImage() throws -> CGImage {
    guard let ctx = CGContext(
        data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw TestImageError.contextCreationFailed
    }
    ctx.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    guard let image = ctx.makeImage() else {
        throw TestImageError.contextCreationFailed
    }
    return image
}

private enum TestImageError: Error { case contextCreationFailed }