import AppKit
import Foundation
import Testing
@testable import PluginEditorPreview

/// 回归 #1194：预览图片不得在 `View.body` 里同步 `NSImage(contentsOf:)`。
/// 改为后台加载 + 最新选中优先的代次校验，视图只渲染已准备好的图片。
@MainActor
@Suite("Editor preview image loading")
struct EditorPreviewImageLoadTests {

    @Test("图片打开在后台线程执行")
    func loadRunsOffMain() async throws {
        let url = try makePNGFile(width: 20, height: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        let size = await Task.detached(priority: .userInitiated) {
            Self.runLoadOffMain(url: url, flag: flag)
        }.value

        #expect(flag.value == false, "图片打开/解码不应发生在主线程")
        #expect(try #require(size) == NSSize(width: 20, height: 10))
    }

    @Test("打不开的文件返回 nil")
    func unreadableFileReturnsNil() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")

        #expect(EditorPreviewImageLoader.loadBox(at: missing) == nil)
        #expect(await EditorPreviewImageLoader.load(at: missing) == nil)
    }

    @Test("选中图片后异步发布已加载的图片")
    func publishesLoadedImage() async throws {
        let url = try makePNGFile(width: 20, height: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = EditorPreviewViewModel(projectCapability: StubCapability(url: url))
        await waitUntil { viewModel.previewImage != nil }

        #expect(viewModel.state == .image(url.standardizedFileURL))
        #expect(viewModel.previewImage?.size == NSSize(width: 20, height: 10))
    }

    @Test("晚到的旧选中图片不覆盖最新选中")
    func staleSelectionDoesNotOverwrite() async throws {
        let first = try makePNGFile(width: 20, height: 10)
        let second = try makePNGFile(width: 40, height: 20)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let loader = GatedImageLoader()
        loader.blockFirst = true
        let viewModel = EditorPreviewViewModel(
            projectCapability: StubCapability(url: first),
            imageLoader: { await loader.load($0) }
        )
        await waitUntil { loader.calls == 1 }

        // 旧加载仍挂起时切换选中：新图片先完成。
        viewModel.updateCurrentFile(second)
        await waitUntil { viewModel.previewImage != nil }
        #expect(viewModel.previewImage?.size == NSSize(width: 40, height: 20))

        // 放行旧加载：它的结果必须被丢弃。
        loader.release()
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.previewImage?.size == NSSize(width: 40, height: 20))
        #expect(viewModel.state == .image(second.standardizedFileURL))
    }

    @Test("图片打不开时进入失败态而不是渲染空图")
    func unreadableImageFails() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")

        let viewModel = EditorPreviewViewModel(projectCapability: StubCapability(url: url))
        await waitUntil {
            if case .failed = viewModel.state { return true }
            return false
        }

        #expect(viewModel.previewImage == nil)
    }

    // MARK: - Helpers

    /// 同步执行，才能在闭包内读取 `Thread.isMainThread`（异步上下文不可用）。
    nonisolated private static func runLoadOffMain(url: URL, flag: ThreadFlag) -> NSSize? {
        flag.value = Thread.isMainThread
        return EditorPreviewImageLoader.loadBox(at: url)?.image.size
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func makePNGFile(width: Int, height: Int) throws -> URL {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-preview-image-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }
}

@MainActor
private final class StubCapability: EditorPreviewProjectCapability {
    var currentFileURL: URL?

    init(url: URL?) {
        self.currentFileURL = url
    }
}

/// 第一次加载挂起在门闩上，用于构造「旧请求晚到」。
@MainActor
private final class GatedImageLoader {
    var blockFirst = false
    private(set) var calls = 0
    private var gate: CheckedContinuation<Void, Never>?

    func load(_ url: URL) async -> EditorPreviewImageLoader.Box? {
        calls += 1
        if blockFirst {
            blockFirst = false
            await withCheckedContinuation { gate = $0 }
        }
        return EditorPreviewImageLoader.loadBox(at: url)
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}