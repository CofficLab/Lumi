import AppKit
import Foundation
import KitTestSupport
import Testing
@testable import ClipboardManagerPlugin

/// 回归 #242：剪贴板图片历史把临时目录路径持久化，清理后条目永久损坏。
///
/// 剪贴板历史是持久 SwiftData，但图片 PNG 此前默认写入系统临时目录
/// （`FileManager.default.temporaryDirectory`）。系统清理临时文件后，数据库
/// 仍保留指向已消失文件的记录，重启也无法恢复。
///
/// 这些测试锁住修复后的契约：生产采集入口 `captureItems` 必须把图片写进
/// 插件自有的持久目录（`ClipboardManagerRuntime.imageDirectory()`，即
/// `<dataRoot>/images`），而不是系统临时目录；首次采集时该目录可能尚不存在，
/// 落盘前必须先创建。
///
/// 注入目录是进程级共享状态，可能与其它用例并发读写，故本套件串行化并在
/// 主 actor 上运行；每个用例在 `await` 之前同步解析出期望目录，避免悬起期间
/// 注入被其它用例清空。
@MainActor
@Suite("剪贴板图片持久化", .serialized)
struct ClipboardImagePersistenceTests {

    @Test("图片目录位于插件数据根目录下，而非系统临时目录")
    func imageDirectoryIsUnderPluginDataRoot() throws {
        let root = try TemporaryDirectory.make("clipboard-image-persistence")
        ClipboardManagerRuntime.injectedDatabaseDirectory = root.url
        defer {
            ClipboardManagerRuntime.injectedDatabaseDirectory = nil
            root.remove()
        }

        let imageDirectory = ClipboardManagerRuntime.imageDirectory()

        #expect(
            imageDirectory.path.hasPrefix(root.url.path),
            "图片目录必须在插件数据根目录下，实际 \(imageDirectory.path)"
        )
        #expect(
            imageDirectory.deletingLastPathComponent().path == root.url.path,
            "图片目录应是数据根目录的直接子目录"
        )
        #expect(imageDirectory.lastPathComponent == "images")
    }

    @Test("生产采集入口把图片写进持久图片目录并返回该路径")
    func captureItemsWritesImageIntoPersistentDirectory() async throws {
        let root = try TemporaryDirectory.make("clipboard-image-persistence")
        ClipboardManagerRuntime.injectedDatabaseDirectory = root.url
        defer {
            ClipboardManagerRuntime.injectedDatabaseDirectory = nil
            root.remove()
        }
        // 同步解析期望目录：await 之前注入不会被其它用例清空。
        let expectedDirectory = ClipboardManagerRuntime.imageDirectory()

        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([Self.makeImage()])

        let items = await ClipboardMonitor.captureItems(from: pasteboard, appName: "TestApp")

        let item = try #require(items.first, "生产采集应返回一条图片条目")
        #expect(item.type == .image)
        #expect(
            item.content.hasPrefix(expectedDirectory.path),
            "图片路径必须落在持久图片目录下，实际 \(item.content)"
        )
        #expect(
            FileManager.default.fileExists(atPath: item.content),
            "返回的图片路径必须真实存在"
        )
        // 不得再落进系统临时目录的根（旧缺陷路径形如 /tmp/clipboard_<UUID>.png）。
        #expect(
            URL(fileURLWithPath: item.content).deletingLastPathComponent().path
                != FileManager.default.temporaryDirectory.path,
            "图片不得直接写入系统临时目录根"
        )
    }

    @Test("首次采集时持久图片目录尚不存在也能成功落盘")
    func captureItemsCreatesImageDirectoryOnFirstUse() async throws {
        let root = try TemporaryDirectory.make("clipboard-image-persistence")
        ClipboardManagerRuntime.injectedDatabaseDirectory = root.url
        defer {
            ClipboardManagerRuntime.injectedDatabaseDirectory = nil
            root.remove()
        }
        // 前置条件：数据根目录存在，但 images 子目录尚未创建。同步解析。
        let imageDirectory = ClipboardManagerRuntime.imageDirectory()
        #expect(!FileManager.default.fileExists(atPath: imageDirectory.path))

        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([Self.makeImage()])

        let items = await ClipboardMonitor.captureItems(from: pasteboard, appName: "TestApp")

        #expect(items.first?.type == .image, "目录不存在时仍应成功采集图片")
        #expect(FileManager.default.fileExists(atPath: imageDirectory.path), "落盘前应创建图片目录")
    }

    // MARK: - Helpers

    private nonisolated static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        return image
    }
}