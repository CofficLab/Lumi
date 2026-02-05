import Foundation
import AppKit
import Combine
import OSLog

@MainActor
class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    @Published var lastChangeCount: Int
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private let logger = Logger(subsystem: "com.lumi.clipboard", category: "Monitor")
    
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
        logger.info("Clipboard monitoring started")
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitoring stopped")
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
            logger.info("Captured text clipboard item")
        }
        // Add more types later (Image, File, etc.)
    }
}
