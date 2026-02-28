import Foundation
import MagicKit
import AppKit
import ApplicationServices
import Combine
import OSLog

@MainActor
class TextSelectionManager: ObservableObject, SuperLog {
    static let shared = TextSelectionManager()
    
    @Published var selectedText: String?
    @Published var selectionRect: CGRect?
    @Published var isPermissionGranted: Bool = false
    
    private var monitor: Any?
    private let logger = Logger(subsystem: "com.lumi.textactions", category: "SelectionManager")
    
    private init() {
        checkPermission()
    }
    
    func checkPermission() {
        // AXIsProcessTrustedWithOptions and kAXTrustedCheckOptionPrompt usage
        // usage of kAXTrustedCheckOptionPrompt directly causes concurrency error (shared mutable state)
        // Check silently (don't force prompt on app launch)
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
    }
    
    nonisolated func startMonitoring() {
        Task { @MainActor in
            guard monitor == nil else { return }
            
            // Monitor global mouse up events
            monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleMouseUp(event)
                }
            }
            os_log("\(Self.t)Started monitoring text selection")
        }
    }
    
    nonisolated func stopMonitoring() {
        Task { @MainActor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            os_log("\(Self.t)Stopped monitoring text selection")
        }
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        guard isPermissionGranted else { return }
        
        // Use a detached task to perform AX operations to avoid blocking the main thread
        Task.detached(priority: .userInitiated) {
            let result = self.getSelectedText()
            
            await MainActor.run {
                if let (text, rect) = result, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.selectedText = text
                    self.selectionRect = rect
                    os_log("\(Self.t)Detected selection: \(text.prefix(20))...")
                } else {
                    // Hide menu if clicking elsewhere
                    self.selectedText = nil
                    self.selectionRect = nil
                }
            }
        }
    }
    
    nonisolated private func getSelectedText() -> (String, CGRect)? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        // Get focused element
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement as! AXUIElement? else { return nil }
        
        // Get selected text
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        guard textResult == .success, let text = selectedTextValue as? String else { return nil }
        
        // Try to get bounds (this is tricky for text selection, often we just get the element bounds or mouse position)
        // For simplicity, we'll use the current mouse location as the anchor
        let mouseLoc = NSEvent.mouseLocation
        // Convert screen coordinates (bottom-left origin) to window coordinates (top-left origin) logic happens in the view
        // But here we just return the screen rect.
        // Let's assume a small rect around the mouse cursor for now.
        // Ideally we would use kAXBoundsForRangeParameterizedAttribute but that's complex.
        
        let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 0, height: 0)
        
        return (text, rect)
    }
}
