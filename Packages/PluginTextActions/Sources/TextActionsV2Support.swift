import AppKit
import ApplicationServices
import ProviderLLMManager
import SwiftUI

enum TextActionsSettings {
    static let enabledKey = "TextActions.enabled"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    @MainActor static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        enabled ? TextSelectionManager.shared.startMonitoring() : TextSelectionManager.shared.stopMonitoring()
    }
}

@MainActor
final class TextSelectionManager {
    static let shared = TextSelectionManager()
    private var monitor: Any?
    private(set) var isPermissionGranted = false
    private init() { refreshPermission() }
    func refreshPermission() { isPermissionGranted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary) }
    func requestPermission() {
        isPermissionGranted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if !isPermissionGranted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    func startMonitoring() {
        guard monitor == nil else { return }; refreshPermission(); guard isPermissionGranted else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .keyUp]) { _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                let system = AXUIElementCreateSystemWide(); var focused: CFTypeRef?
                guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return }
                var selected: CFTypeRef?
                guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success, let text = selected as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                TextActionMenuController.shared.show(text: text, at: point)
            }
        }
    }
    func stopMonitoring() { if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }; TextActionMenuController.shared.hide() }
}

@MainActor
final class TextActionMenuController {
    static let shared = TextActionMenuController()
    private var alert: NSAlert?
    private var translationProvider: (any LLMManaging)?
    func configure(translationProvider: any LLMManaging) { self.translationProvider = translationProvider }
    func show(text: String, at _: CGPoint) {
        hide()
        let alert = NSAlert(); alert.messageText = "Text Actions"; alert.informativeText = text; alert.addButton(withTitle: "Copy"); alert.addButton(withTitle: "Search"); alert.addButton(withTitle: "Cancel"); self.alert = alert
        let response = alert.runModal(); defer { self.alert = nil }
        if response == .alertFirstButtonReturn { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
        if response == .alertSecondButtonReturn, var components = URLComponents(string: "https://www.google.com/search") { components.queryItems = [URLQueryItem(name: "q", value: text)]; if let url = components.url { NSWorkspace.shared.open(url) } }
    }
    func hide() { alert?.window.orderOut(nil); alert = nil }
}

struct TextActionsSettingsView: View {
    @State private var enabled = TextActionsSettings.isEnabled
    var body: some View {
        Form {
            Toggle(LumiPluginLocalization.string("Enable selected-text actions", bundle: .module), isOn: $enabled).onChange(of: enabled) { _, value in TextActionsSettings.setEnabled(value) }
            Button(LumiPluginLocalization.string("Request Accessibility Permission", bundle: .module)) { TextSelectionManager.shared.requestPermission() }
        }.padding()
    }
}
