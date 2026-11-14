import AppKit
import Combine
import Foundation
import LumiLoggingKit
import os

@MainActor
public class ClipboardMonitor: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = ClipboardManagerPluginSupport.logger

    public static let shared = ClipboardMonitor()

    @Published var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general

    /// 生命周期代次。
    ///
    /// 每次「停止监控」都会推进代次。已经在处理中的内容（尤其是图片编码，
    /// 它跑在独立的 detached Task 里，取消定时器并不会让它停下）
    /// 在写文件与写库之前都会检查代次，代次已变就丢弃结果
    /// （见 issue #423）。
    private var lifecycleGeneration = ClipboardLifecycleGeneration()

    // Dependencies
    private let storage = ClipboardStorage.shared

    private init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    public func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
    }

    public func stopMonitoring() {
        // 让在途处理失效：它们完成后不会再写文件、写库或发通知。
        lifecycleGeneration.stop()
        if Self.verbose {
            Self.logger.info("\(Self.t)🛑 Clipboard monitoring stopped")
        }
    }

    /// 当前生命周期代次。仅供单元测试断言「停止监控会让在途处理失效」。
    var lifecycleGenerationForTesting: UInt64 { lifecycleGeneration.current }

    func poll() {
        checkForChanges()
    }

    private func checkForChanges() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            processPasteboardContent()
        }
    }

    private func processPasteboardContent() {
        // 记录启动时的代次：处理期间若发生「停止监控」，代次会变，结果被丢弃。
        let generation = lifecycleGeneration.begin()
        Task {
            let items = await Self.itemsAsync(
                from: pasteboard,
                appName: NSWorkspace.shared.frontmostApplication?.localizedName,
                isStillActive: { [weak self] in
                    await MainActor.run { self?.lifecycleGeneration.isCurrent(generation) ?? false }
                }
            )

            for item in items {
                // 监控已停止：不再写入，也不再通知。
                guard await MainActor.run(body: { self.lifecycleGeneration.isCurrent(generation) }) else {
                    return
                }
                await storage.add(item: item)
                await MainActor.run {
                    guard self.lifecycleGeneration.isCurrent(generation) else { return }
                    ClipboardHistoryChangeCenter.shared.notify()
                }

                if Self.verbose {
                    if ClipboardManagerPluginSupport.verbose {
                        ClipboardManagerPluginSupport.logger.info("\(Self.t)\(Self.logMessage(for: item))")
                    }
                }
            }
        }
    }

    // MARK: - Items Extraction (Async for Image Processing)

    /// Extracts clipboard items asynchronously by moving image encoding/writing to background
    static func itemsAsync(
        from pasteboard: NSPasteboard,
        appName: String?,
        imageDirectory: URL = FileManager.default.temporaryDirectory,
        isStillActive: (@Sendable () async -> Bool)? = nil
    ) async -> [ClipboardItem] {
        // Handle file URLs first (sync, no I/O)
        if let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let fileItems = fileUrls
                .filter(\.isFileURL)
                .map { ClipboardItem(type: .file, content: $0.path, appName: appName) }
            if !fileItems.isEmpty {
                return fileItems
            }
        }

        // Handle image in background Task
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // 监控已停止：不再写 PNG 文件（见 issue #423）。
            if let isStillActive, await isStillActive() == false { return [] }
            let imagePath = await saveImageAsync(image, to: imageDirectory)
            if let path = imagePath {
                return [ClipboardItem(type: .image, content: path, appName: appName)]
            }
        }

        // Handle text (sync)
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            if let fileItems = fileItems(fromString: str, appName: appName), !fileItems.isEmpty {
                return fileItems
            }
            // 同时抓取 RTF / HTML，回写时才能恢复格式与链接目标；超出上限的负载
            // 会在 ClipboardItem 初始化时整体丢弃，退化为纯文本。
            let richText = richTextPayloads(from: pasteboard)
            return [ClipboardItem(
                type: .text,
                content: str,
                appName: appName,
                richTextRTF: richText.rtf,
                richTextHTML: richText.html
            )]
        }

        return []
    }

    /// 读取剪贴板里的富文本表示。HTML 可能非常大，交给 ClipboardItem 统一限流。
    private static func richTextPayloads(from pasteboard: NSPasteboard) -> (rtf: Data?, html: String?) {
        let rtf = pasteboard.data(forType: .rtf)
        let html = pasteboard.data(forType: .html)
            .flatMap { String(data: $0, encoding: .utf8) }
        return (rtf, html)
    }

    /// Saves image to disk in background Task, returns path on success
    private static func saveImageAsync(_ image: NSImage, to directory: URL) async -> String? {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let result = Self.saveImage(image, to: directory)
                continuation.resume(returning: result)
            }
        }
    }

    private static func fileItems(fromString string: String, appName: String?) -> [ClipboardItem]? {
        let lines = string
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var urls: [URL] = []
        for line in lines {
            guard let url = fileURL(fromClipboardString: line),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            urls.append(url)
        }

        return urls.map { ClipboardItem(type: .file, content: $0.path, appName: appName) }
    }

    private static func fileURL(fromClipboardString string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        if trimmed.lowercased().hasPrefix("file://") {
            let rawPath = String(trimmed.dropFirst("file://".count))
            let path = rawPath
                .replacingOccurrences(of: "^localhost", with: "", options: .regularExpression)
                .removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
        }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        if trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
        }
        return nil
    }

    private nonisolated static func saveImage(_ image: NSImage, to directory: URL) -> String? {
        let imageURL = directory.appendingPathComponent("clipboard_\(UUID().uuidString).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: imageURL)
            return imageURL.path
        } catch {
            Self.logger.error("\(Self.t)❌ Failed to save image: \(error.localizedDescription)")

            return nil
        }
    }

    private static func logMessage(for item: ClipboardItem) -> String {
        switch item.type {
        case .text, .html, .color:
            return "📝 Captured text clipboard item"
        case .image:
            return "🖼️ Captured image clipboard item"
        case .file:
            return "📁 Captured file clipboard item: \(URL(fileURLWithPath: item.content).lastPathComponent)"
        }
    }
}
