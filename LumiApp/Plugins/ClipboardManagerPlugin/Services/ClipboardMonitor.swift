import Foundation
import MagicKit
import AppKit
import Combine

@MainActor
class ClipboardMonitor: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false
    
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
        ClipboardManagerPlugin.logger.info("\(Self.t)Clipboard monitoring stopped")
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
            // Avoid duplicates if the last item is identical?
            // EcoPaste logic: deduplicate
            
            let item = ClipboardItem(type: .text, content: str, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
            Task {
                await storage.add(item: item)
                await MainActor.run {
                    NotificationCenter.default.post(name: .clipboardHistoryDidUpdate, object: nil)
                }
            }
            
            if Self.verbose {
                ClipboardManagerPlugin.logger.info("\(Self.t)Captured text clipboard item")
            }
        }
        // Add more types later (Image, File, etc.)
    }
}
