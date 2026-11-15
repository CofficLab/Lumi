import AppKit
import Foundation
import Testing

@testable import PluginAppStoreConnect

/// 截图导入的图片读取与尺寸校验必须在后台线程执行（Issue #1199）。
@Suite("ASC screenshot import off-main")
struct ScreenshotImportOffMainTests {

    @Test("readScreenshotItem 在后台线程读取合法图片并判定 ready")
    func readRunsOffMain() async throws {
        let url = try Self.makePNG(width: 400, height: 400)
        defer { try? FileManager.default.removeItem(at: url) }
        let flag = ThreadFlag()

        let item = await Task.detached(priority: .userInitiated) {
            Self.runReadOffMain(flag: flag, url: url, displayType: "APP_IPHONE_67")
        }.value

        #expect(flag.value == false, "图片读取与校验必须在非主线程执行")
        #expect(item.width == 400)
        #expect(item.height == 400)
        #expect(item.status == .ready)
        #expect(item.displayType == "APP_IPHONE_67")
    }

    @Test("不可读图片在后台线程判定为 invalid")
    func unreadableImageIsInvalid() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let flag = ThreadFlag()

        let item = await Task.detached(priority: .userInitiated) {
            Self.runReadOffMain(flag: flag, url: url, displayType: "APP_IPHONE_67")
        }.value

        #expect(flag.value == false)
        #expect(item.width == 0)
        #expect(item.height == 0)
        guard case .invalid = item.status else {
            Issue.record("不可读图片应判定为 invalid")
            return
        }
    }

    /// 同步辅助函数：记录当前线程并调用生产读取逻辑。
    ///
    /// `Thread.isMainThread` 在 async 上下文不可用，必须放在同步函数里。
    private static func runReadOffMain(flag: ThreadFlag, url: URL, displayType: String) -> PendingScreenshot {
        flag.value = Thread.isMainThread
        return VM.readScreenshotItem(url: url, displayType: displayType)
    }

    private static func makePNG(width: Int, height: Int) throws -> URL {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ScreenshotImportOffMainTests", code: 1)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        try data.write(to: url)
        return url
    }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}