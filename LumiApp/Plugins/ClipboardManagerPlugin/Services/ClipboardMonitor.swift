import Foundation
import MagicKit
import AppKit
import Combine

@MainActor
class ClipboardMonitor: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false    
    static let shared = ClipboardMonitor()
    
    @Published var lastChangeCount: Int
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general

    // Dependencies
    private let storage = ClipboardStorage.shared
    
    private init() {
        self.lastChangeCount = pasteboard.changeCount
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        ClipboardManagerPlugin.logger.info("\(Self.t)🛑 Clipboard monitoring stopped")
    }
    
    private func checkForChanges() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            processPasteboardContent()
        }
    }
    
    private func processPasteboardContent() {
        // Determine type and content
        if let str = pasteboard.string(forType: .string) {
            // Text content
            // Avoid duplicates if the last item is identical
            
            let item = ClipboardItem(type: .text, content: str, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
            Task {
                await storage.add(item: item)
                await MainActor.run {
                    NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                }
            }
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)📝 Captured text clipboard item")
            }
        }
        
        // Check for image
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // Save image to file and record
            let tempDir = FileManager.default.temporaryDirectory
            let imageName = "clipboard_\(UUID().uuidString).png"
            let imageURL = tempDir.appendingPathComponent(imageName)
            
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: imageURL)
                    let item = ClipboardItem(type: .image, content: imageURL.path, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
                    Task {
                        await storage.add(item: item)
                        await MainActor.run {
                            NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                        }
                    }
                    
                    if Self.verbose {
                        ClipboardManagerPlugin.logger.info("\(Self.t)🖼️ Captured image clipboard item")
                    }
                } catch {
                    ClipboardManagerPlugin.logger.error("\(Self.t)❌ Failed to save image: \(error.localizedDescription)")
                }
            }
        }
        
        // Check for files - use explicit type annotation
        if let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileUrls where url.isFileURL {
                let item = ClipboardItem(type: .file, content: url.path, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
                Task {
                    await storage.add(item: item)
                    await MainActor.run {
                        NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                    }
                }
                
                if Self.verbose {
                    ClipboardManagerPlugin.logger.info("\(Self.t)📁 Captured file clipboard item: \(url.lastPathComponent)")
                }
            }
        }
    }
}
