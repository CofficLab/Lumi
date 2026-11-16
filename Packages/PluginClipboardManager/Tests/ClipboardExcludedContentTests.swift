import AppKit
import Foundation
import KitTestSupport
import Testing
@testable import ClipboardManagerPlugin

/// Issue #774：携带「禁止留存」标记的剪贴板内容不得进入历史。
///
/// 密码管理器用 `org.nspasteboard.TransientType` / `org.nspasteboard.ConcealedType`
/// 声明内容不得被第三方持久化。旧实现的 `itemsAsync` 不检查这些标记，密码仍被
/// 写入历史与 SwiftData，即使生产者随后清空系统剪贴板，Lumi 的副本仍在。
///
/// 正确行为：命中任一标记即整体跳过——不返回条目、不写库、不写图片文件。
@MainActor
@Suite("剪贴板禁止留存标记（#774）")
struct ClipboardExcludedContentTests {
    private let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        return image
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-excluded-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("concealed 标记的文本不进入历史")
    func concealedTextIsNotCollected() async {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, concealed], owner: nil)
        pasteboard.setString("super-secret-password", forType: .string)

        let items = await ClipboardMonitor.itemsAsync(from: pasteboard, appName: "PasswordManager")
        #expect(items.isEmpty, "concealed 内容仍被收集：\(items)")
    }

    @Test("transient 标记的文本不进入历史")
    func transientTextIsNotCollected() async {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, transient], owner: nil)
        pasteboard.setString("one-time-token", forType: .string)

        let items = await ClipboardMonitor.itemsAsync(from: pasteboard, appName: "PasswordManager")
        #expect(items.isEmpty, "transient 内容仍被收集：\(items)")
    }

    @Test("concealed 标记的图片不进入历史，也不写图片文件")
    func concealedImageIsNotCollectedAndNoFileWritten() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.tiff, concealed], owner: nil)
        let tiff = try #require(makeImage().tiffRepresentation)
        pasteboard.setData(tiff, forType: .tiff)

        let items = await ClipboardMonitor.itemsAsync(
            from: pasteboard,
            appName: "PasswordManager",
            imageDirectory: directory
        )
        #expect(items.isEmpty, "concealed 图片仍被收集：\(items)")
        let written = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(written.isEmpty, "concealed 图片仍写出了文件：\(written)")
    }

    @Test("无标记的普通文本仍正常收集（不回归）")
    func unmarkedTextIsStillCollected() async {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("normal clipboard text", forType: .string)

        let items = await ClipboardMonitor.itemsAsync(from: pasteboard, appName: "Editor")
        #expect(items.count == 1)
        #expect(items.first?.type == .text)
        #expect(items.first?.content == "normal clipboard text")
    }

    @Test("isExcludedFromHistory 精确识别两种标记")
    func detectsExclusionMarkers() {
        let plain = NSPasteboard.withUniqueName()
        plain.clearContents()
        plain.setString("hello", forType: .string)
        #expect(!ClipboardMonitor.isExcludedFromHistory(plain))

        let concealedBoard = NSPasteboard.withUniqueName()
        concealedBoard.clearContents()
        concealedBoard.declareTypes([.string, concealed], owner: nil)
        concealedBoard.setString("secret", forType: .string)
        #expect(ClipboardMonitor.isExcludedFromHistory(concealedBoard))

        let transientBoard = NSPasteboard.withUniqueName()
        transientBoard.clearContents()
        transientBoard.declareTypes([.string, transient], owner: nil)
        transientBoard.setString("token", forType: .string)
        #expect(ClipboardMonitor.isExcludedFromHistory(transientBoard))
    }
}