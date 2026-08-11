import AppKit
import ApplicationServices
import Combine
import LumiUI
import SwiftUI

enum TextActionsSettings {
    static let enabledKey = "TextActions.enabled"
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if enabled {
            TextSelectionManager.shared.startMonitoring()
        } else {
            TextSelectionManager.shared.stopMonitoring()
        }
    }
}

@MainActor
final class TextSelectionManager: ObservableObject {
    static let shared = TextSelectionManager()

    @Published private(set) var isPermissionGranted = false
    private var monitor: Any?

    private init() {
        refreshPermission()
    }

    func refreshPermission() {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
    }

    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
        if !isPermissionGranted {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        refreshPermission()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            let mouseLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleMouseUp(event, mouseLocation: mouseLocation)
            }
        }
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        TextActionMenuController.shared.hide()
    }

    private func handleMouseUp(_ event: NSEvent, mouseLocation: CGPoint) {
        guard isPermissionGranted else { return }
        Task.detached(priority: .userInitiated) {
            let result = Self.readSelectedText(anchor: mouseLocation)
            await MainActor.run {
                if let result, !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TextActionMenuController.shared.show(text: result.text, at: result.anchor)
                } else {
                    TextActionMenuController.shared.hide()
                }
            }
        }
    }

    nonisolated private static func readSelectedText(anchor: CGPoint) -> SelectedText? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success else { return nil }
        guard let focusedValue else { return nil }
        let focused = focusedValue as! AXUIElement

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let text = selectedValue as? String else { return nil }

        return SelectedText(text: text, anchor: anchor)
    }
}

private struct SelectedText: Sendable {
    let text: String
    let anchor: CGPoint
}

@MainActor
final class TextActionMenuController {
    static let shared = TextActionMenuController()

    private var window: NSPanel?

    func show(text: String, at point: CGPoint) {
        if window == nil {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            window = panel
        }

        window?.contentView = NSHostingView(
            rootView: TextActionMenuView(text: text) { [weak self] action in
                action.perform(with: text)
                self?.hide()
            }
        )

        let size = window?.contentView?.fittingSize ?? CGSize(width: 180, height: 70)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let maxX = (screen?.frame.maxX ?? point.x + size.width) - size.width - 8
        let maxY = (screen?.frame.maxY ?? point.y + size.height) - size.height - 8
        let frame = CGRect(
            x: min(max(point.x - size.width / 2, screen?.frame.minX ?? point.x), maxX),
            y: min(point.y + 18, maxY),
            width: size.width,
            height: size.height
        )
        window?.setFrame(frame, display: true)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

enum TextAction: CaseIterable, Identifiable {
    case copy
    case search

    var id: Self { self }
    var title: String {
        switch self {
        case .copy: LumiPluginLocalization.string("Copy", bundle: .module)
        case .search: LumiPluginLocalization.string("Search", bundle: .module)
        }
    }
    var systemImage: String {
        switch self {
        case .copy: "doc.on.doc"
        case .search: "magnifyingglass"
        }
    }

    func perform(with text: String) {
        switch self {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .search:
            guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
            NSWorkspace.shared.open(url)
        }
    }
}

struct TextActionMenuView: View {
    let text: String
    let action: (TextAction) -> Void

    var body: some View {
        AppCard(style: .glass, cornerRadius: 12, padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) {
            HStack(spacing: 6) {
                ForEach(TextAction.allCases) { item in
                    AppButton(item.title, systemImage: item.systemImage, style: .tonal, size: .small) {
                        action(item)
                    }
                }
            }
        }
        .fixedSize()
        .accessibilityLabel(Text(text.prefix(80)))
    }
}

struct TextActionsSettingsView: View {
    @ObservedObject private var manager = TextSelectionManager.shared
    @State private var isEnabled = TextActionsSettings.isEnabled
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppCard {
                    HStack(spacing: 12) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(theme.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LumiPluginLocalization.string("Text Actions", bundle: .module))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(theme.textPrimary)
                            Text(LumiPluginLocalization.string("Selected Text Actions", bundle: .module))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                AppSettingsSection(
                    title: LumiPluginLocalization.string("Text Actions", bundle: .module),
                    subtitle: LumiPluginLocalization.string("Show a floating menu after selecting text in another macOS app.", bundle: .module)
                ) {
                    AppSettingsToggleRow(
                        LumiPluginLocalization.string("Enable Text Actions", bundle: .module),
                        description: LumiPluginLocalization.string("Show a floating menu after selecting text in another macOS app.", bundle: .module),
                        systemImage: "cursorarrow.rays",
                        isOn: $isEnabled
                    )
                    .onChange(of: isEnabled) { _, value in
                        TextActionsSettings.setEnabled(value)
                    }
                }

                AppCard(style: .subtle) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            manager.isPermissionGranted
                                ? LumiPluginLocalization.string("Accessibility permission granted", bundle: .module)
                                : LumiPluginLocalization.string("Accessibility permission not granted", bundle: .module),
                            systemImage: manager.isPermissionGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                        )
                        .foregroundStyle(manager.isPermissionGranted ? theme.success : theme.warning)

                        Text(LumiPluginLocalization.string("Accessibility permission is required to read selected text from other apps.", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)

                        if !manager.isPermissionGranted {
                            AppButton(
                                LumiPluginLocalization.string("Open System Settings", bundle: .module),
                                systemImage: "gear",
                                style: .secondary,
                                size: .small
                            ) {
                                manager.requestPermission()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            manager.refreshPermission()
            isEnabled = TextActionsSettings.isEnabled
        }
    }
}
