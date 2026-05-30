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
        let items = Self.items(
            from: pasteboard,
            appName: NSWorkspace.shared.frontmostApplication?.localizedName
        )

        for item in items {
            Task {
                await storage.add(item: item)
                await MainActor.run {
                    NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                }
            }
            
            if Self.verbose {
                if ClipboardManagerPlugin.verbose {
                    ClipboardManagerPlugin.logger.info("\(Self.t)\(Self.logMessage(for: item))")
                }
            }
        }
    }

    static func items(
        from pasteboard: NSPasteboard,
        appName: String?,
        imageDirectory: URL = FileManager.default.temporaryDirectory
    ) -> [ClipboardItem] {
        if let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let fileItems = fileUrls
                .filter(\.isFileURL)
                .map { ClipboardItem(type: .file, content: $0.path, appName: appName) }
            if !fileItems.isEmpty {
                return fileItems
            }
        }

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let imagePath = saveImage(image, to: imageDirectory) {
            return [ClipboardItem(type: .image, content: imagePath, appName: appName)]
        }

        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            return [ClipboardItem(type: .text, content: str, appName: appName)]
        }

        return []
    }

    private static func saveImage(_ image: NSImage, to directory: URL) -> String? {
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
