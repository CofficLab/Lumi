import AppKit
import Foundation
import Testing
@testable import ClipboardManagerPlugin

/// 剪贴板图片复制的后台加载（见 issue #1198）。
///
/// 原先 `copyToClipboard` 在主 actor 上同步 `NSImage(contentsOfFile:)`，
/// 大图或慢盘时每次双击 / 右键复制都会卡住 UI。
@MainActor
@Suite("剪贴板图片复制")
struct ClipboardImageCopyOffMainTests {

    @Test("图片加载在后台线程执行")
    func loadRunsOffMain() async throws {
        let url = try makePNGFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        let loaded = await Task.detached(priority: .userInitiated) {
            Self.runLoadOffMain(path: url.path, flag: flag)
        }.value

        #expect(flag.value == false)
        #expect(loaded)
    }

    @Test("缺失文件返回 nil 且不清空剪贴板")
    func missingFileReturnsNil() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        #expect(pasteboard.setString("original", forType: .string))

        let item = ClipboardHistoryItem(
            type: ClipboardItemType.image.rawValue,
            content: "/definitely/missing/image-\(UUID().uuidString).png",
            searchKeywords: "x"
        )

        #expect(ClipboardManagerViewModel.loadImageBox(atPath: item.content) == nil)
        #expect(ClipboardManagerViewModel.write(item, to: pasteboard) == false)
        #expect(pasteboard.string(forType: .string) == "original")
    }

    @Test("预加载图片写入时不再重读文件")
    func preloadedImageSkipsReload() throws {
        let url = try makePNGFile()
        let image = try #require(NSImage(contentsOfFile: url.path))
        // 删除源文件：只有走预加载分支才可能写入成功。
        try FileManager.default.removeItem(at: url)

        let pasteboard = NSPasteboard.withUniqueName()
        let item = ClipboardHistoryItem(
            type: ClipboardItemType.image.rawValue,
            content: url.path,
            searchKeywords: "x"
        )

        #expect(ClipboardManagerViewModel.write(item, to: pasteboard, preloadedImage: image))
        #expect(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
    }

    // MARK: - Helpers

    /// 同步执行，才能在闭包内读取 `Thread.isMainThread`（异步上下文不可用）。
    nonisolated private static func runLoadOffMain(path: String, flag: ThreadFlag) -> Bool {
        flag.value = Thread.isMainThread
        return ClipboardManagerViewModel.loadImageBox(atPath: path) != nil
    }

    private func makePNGFile() throws -> URL {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()

        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipCopyTests-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}