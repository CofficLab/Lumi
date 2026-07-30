import Foundation
import SuperLogKit
import AppKit
import Combine

@MainActor
public class ClipboardMonitor: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    
    public static let shared = ClipboardMonitor()
    
    @Published var lastChangeCount: Int
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general

    // Dependencies
    private let storage = ClipboardStorage.shared
    
    private init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    public func startMonitoring() {
        guard timer == nil else { return }

        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if Self.verbose {
            if ClipboardManagerPlugin.verbose {
                            ClipboardManagerPlugin.logger.info("\(Self.t)🛑 Clipboard monitoring stopped")
            }
        }
    }
    
    private func checkForChanges() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            processPasteboardContent()
        }
    }
    
    private func processPasteboardContent() {
        Task {
            let items = await Self.itemsAsync(
                from: pasteboard,
                appName: NSWorkspace.shared.frontmostApplication?.localizedName
            )

            for item in items {
                await storage.add(item: item)
                await MainActor.run {
                    NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                }

                if Self.verbose {
                    if ClipboardManagerPlugin.verbose {
                        ClipboardManagerPlugin.logger.info("\(Self.t)\(Self.logMessage(for: item))")
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
        imageDirectory: URL = FileManager.default.temporaryDirectory
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
            return [ClipboardItem(type: .text, content: str, appName: appName)]
        }

        return []
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
            if ClipboardManagerPlugin.verbose {
                ClipboardManagerPlugin.logger.error("\(Self.t)❌ Failed to save image: \(error.localizedDescription)")
            }
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
