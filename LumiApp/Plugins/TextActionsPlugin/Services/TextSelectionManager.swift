import Foundation
import MagicKit
import AppKit
import ApplicationServices
import Combine

@MainActor
class TextSelectionManager: ObservableObject, SuperLog {
    nonisolated static let emoji = "✂️"
    nonisolated static let verbose: Bool = false
    
    static let shared = TextSelectionManager()
    
    @Published var selectedText: String?
    @Published var selectionRect: CGRect?
    @Published var isPermissionGranted: Bool = false
    
    private var monitor: Any?
    
    private init() {
        checkPermission()
    }
    
    func checkPermission() {
        // AXIsProcessTrustedWithOptions and kAXTrustedCheckOptionPrompt usage
        // usage of kAXTrustedCheckOptionPrompt directly causes concurrency error (shared mutable state)
        // Check silently (don't force prompt on app launch)
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
        
        if Self.verbose {
            TextActionsPlugin.logger.info("\(self.t) 辅助功能权限状态：\(self.isPermissionGranted ? "✅ 已授予" : "❌ 未授予")")
        }
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
            
            if Self.verbose {
                TextActionsPlugin.logger.info("\(self.t) 开始监控文本选择")
            }
        }
    }
    
    nonisolated func stopMonitoring() {
        Task { @MainActor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            
            if Self.verbose {
                TextActionsPlugin.logger.info("\(self.t) 停止监控文本选择")
            }
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
                    if Self.verbose {
                        TextActionsPlugin.logger.info("\(self.t) 检测到选择：\(text.prefix(50))...")
                    }
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
        // But here we'll use screen coordinates directly for the popup
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let convertedPoint = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
        
        return (text, CGRect(origin: convertedPoint, size: .zero))
    }
}
