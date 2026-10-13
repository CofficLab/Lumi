import AppKit
import ApplicationServices

@MainActor
final class TextSelectionObserver {
    private var monitor: Any?

    init() {
        TextSelectionManager.shared.refreshPermission()
        guard TextSelectionManager.shared.isPermissionGranted else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .keyUp]) { _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                let system = AXUIElementCreateSystemWide()
                var focused: CFTypeRef?
                guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
                      let focused,
                      CFGetTypeID(focused) == AXUIElementGetTypeID() else { return }
                var selected: CFTypeRef?
                guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
                      let text = selected as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                TextActionMenuController.shared.show(text: text, at: point)
            }
        }
    }

    func cancel() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        TextActionMenuController.shared.hide()
    }
}
