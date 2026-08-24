import AppKit
import ApplicationServices
import Combine
import KernelLumi
import KitLLM
import ProviderLLMManager
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
    private let eventMonitor: any TextEventMonitoring
    private let selectedTextProvider: any SelectedTextProviding
    private let permissionChecker: () -> Bool
    private var monitor: Any?

    init(
        eventMonitor: any TextEventMonitoring = SystemTextEventMonitor(),
        selectedTextProvider: any SelectedTextProviding = AccessibilitySelectedTextProvider(),
        permissionChecker: @escaping () -> Bool = {
            let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.eventMonitor = eventMonitor
        self.selectedTextProvider = selectedTextProvider
        self.permissionChecker = permissionChecker
        refreshPermission()
    }

    func refreshPermission() {
        isPermissionGranted = permissionChecker()
    }

    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
        if !isPermissionGranted {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        } else if TextActionsSettings.isEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        refreshPermission()
        guard isPermissionGranted else { return }
        // A selection can be completed with a mouse drag or with Shift/keyboard
        // navigation. Listening only for leftMouseUp misses the latter, and
        // some applications update AXSelectedText only shortly after mouseUp.
        monitor = eventMonitor.addGlobalMonitor(
            matching: [.leftMouseUp, .rightMouseUp, .keyUp]
        ) { [weak self] _ in
            let mouseLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.scheduleSelectionRead(anchor: mouseLocation)
            }
        }
    }

    func stopMonitoring() {
        if let monitor {
            eventMonitor.removeMonitor(monitor)
            self.monitor = nil
        }
        TextActionMenuController.shared.hide()
    }

    private func scheduleSelectionRead(anchor: CGPoint) {
        guard isPermissionGranted else { return }
        Task { @MainActor in
            // AX clients such as browsers often publish the new selection on
            // the next run-loop turn. A short retry makes selection detection
            // reliable without polling continuously.
            try? await Task.sleep(for: TextSelectionReadPolicy.initialDelay)
            for attempt in 0..<TextSelectionReadPolicy.retryCount {
                if let result = selectedTextProvider.readSelectedText(anchor: anchor),
                   TextSelectionReadPolicy.shouldPresentMenu(for: result.text) {
                    TextActionMenuController.shared.show(text: result.text, at: result.anchor)
                    return
                }
                if attempt < TextSelectionReadPolicy.retryCount - 1 {
                    try? await Task.sleep(for: TextSelectionReadPolicy.retryDelay)
                }
            }

            TextActionMenuController.shared.hide()
        }
    }

}

struct SelectedText: Sendable, Equatable {
    let text: String
    let anchor: CGPoint
}

@MainActor
protocol SelectedTextProviding {
    func readSelectedText(anchor: CGPoint) -> SelectedText?
}

@MainActor
struct AccessibilitySelectedTextProvider: SelectedTextProviding {
    nonisolated func readSelectedText(anchor: CGPoint) -> SelectedText? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success else { return nil }
        guard let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
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

@MainActor
protocol TextEventMonitoring {
    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any?
    func removeMonitor(_ monitor: Any)
}

@MainActor
private final class SystemTextEventMonitor: TextEventMonitoring {
    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

@MainActor
final class TextActionMenuController {
    static let shared = TextActionMenuController()

    private var window: NSPanel?
    private weak var kernel: KernelLumi?
    private var translationProvider: (any LLMManaging)?
    private var currentText = ""
    private var currentAnchor = CGPoint.zero
    private var translationState: TranslationState = .idle

    enum TranslationState {
        case idle
        case loading
        case result(String)
        case failure(String)
    }

    func configure(kernel: KernelLumi) {
        self.kernel = kernel
        translationProvider = nil
    }

    func configure(translationProvider: any LLMManaging) {
        kernel = nil
        self.translationProvider = translationProvider
    }

    func show(text: String, at point: CGPoint) {
        currentText = text
        currentAnchor = point
        translationState = .idle
        render()
    }

    private func render() {
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
            rootView: TextActionMenuView(
                text: currentText,
                translationState: translationState
            ) { [weak self] action in
                self?.perform(action)
            }
        )

        let size = window?.contentView?.fittingSize ?? CGSize(width: 180, height: 70)
        let screen = NSScreen.screens.first { $0.frame.contains(currentAnchor) } ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(
            x: currentAnchor.x,
            y: currentAnchor.y,
            width: size.width + 16,
            height: size.height + 26
        )
        let frame = TextActionMenuLayout.frame(
            for: currentAnchor,
            menuSize: size,
            screenFrame: screenFrame
        )
        window?.setFrame(frame, display: true)
        window?.orderFrontRegardless()
    }

    private func perform(_ action: TextAction) {
        guard action == .translate else {
            action.perform(with: currentText)
            hide()
            return
        }

        translationState = .loading
        render()
        Task { @MainActor [weak self] in
            do {
                let result: String
                if let providerManager = self?.translationProvider {
                    result = try await providerManager.complete(
                        TextAction.v2TranslationRequest(for: self?.currentText ?? "")
                    ).content
                } else if let providerManager = self?.kernel?.llmProvider {
                    result = try await providerManager.generateText(
                        TextAction.translationRequest(for: self?.currentText ?? ""),
                        providerID: providerManager.selectedProviderID,
                        model: providerManager.selectedModel
                    )
                } else {
                    throw TextActionTranslationError.noProvider
                }
                guard let self else { return }
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                self.translationState = trimmed.isEmpty ? .failure("The LLM returned an empty translation.") : .result(trimmed)
                self.render()
            } catch {
                self?.translationState = .failure(error.localizedDescription)
                self?.render()
            }
        }
    }

    func hide() {
        window?.orderOut(nil)
    }
}

private enum TextActionTranslationError: LocalizedError {
    case noProvider
    var errorDescription: String? { "No LLM provider is configured." }
}

struct TextActionMenuView: View {
    let text: String
    let translationState: TextActionMenuController.TranslationState
    let action: (TextAction) -> Void

    var body: some View {
        AppCard(style: .glass, cornerRadius: 12, padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) {
            VStack(alignment: .leading, spacing: 8) {
                if case .result(let translation) = translationState {
                    Text(translation)
                        .font(.appBody)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: 320, alignment: .leading)
                    AppButton("Copy Translation", systemImage: "doc.on.doc", style: .secondary, size: .small) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translation, forType: .string)
                    }
                } else if case .failure(let message) = translationState {
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320, alignment: .leading)
                } else if case .loading = translationState {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Translating…")
                            .font(.appCaption)
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(TextAction.allCases) { item in
                            AppButton(item.title, systemImage: item.systemImage, style: .secondary, size: .small) {
                                action(item)
                            }
                            .frame(minWidth: 96)
                            .layoutPriority(1)
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
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
            refreshPermissionAndMonitoring()
            isEnabled = TextActionsSettings.isEnabled
        }
        // System Settings is a separate app. Refresh when Lumi becomes
        // active again so the permission card immediately reflects the
        // user's choice without requiring a view reload.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionAndMonitoring()
            isEnabled = TextActionsSettings.isEnabled
        }
    }

    private func refreshPermissionAndMonitoring() {
        manager.refreshPermission()
        if manager.isPermissionGranted && TextActionsSettings.isEnabled {
            manager.startMonitoring()
        }
    }
}
