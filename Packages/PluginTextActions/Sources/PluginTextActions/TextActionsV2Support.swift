import AppKit
import ApplicationServices
import LumiUI
import ProviderLLMManager
import SwiftUI

enum TextActionsSettings {
    /// 配置落盘在插件专属目录（Binary Plist），不再使用 UserDefaults。
    static var isEnabled: Bool {
        TextActionsPluginLocalStore.shared.isEnabled
    }

    @MainActor static func setEnabled(_ enabled: Bool) {
        TextActionsPluginLocalStore.shared.setEnabled(enabled)
        if enabled {
            TextSelectionManager.shared.startMonitoring()
        } else {
            TextSelectionManager.shared.stopMonitoring()
        }
    }
}

/// 选区监听与读取的调度者。
///
/// 三个依赖全部可注入（事件监听、选区读取、权限检查），默认值是生产实现；
/// 单测注入替身即可覆盖启动/停止/权限/重试时序，而不必碰真实的
/// `NSEvent` 全局监听与 Accessibility 授权弹窗。
@MainActor
final class TextSelectionManager {
    static let shared = TextSelectionManager()

    private(set) var isPermissionGranted = false
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

    /// 幂等：重复调用不会注册第二个监听器。
    ///
    /// 插件可能被反复 enable/disable，若不做 `monitor == nil` 短路，
    /// 同一事件会触发多次选区读取并叠加多个浮层。
    func startMonitoring() {
        guard monitor == nil else { return }
        refreshPermission()
        guard isPermissionGranted else { return }
        // 选区既可能由鼠标拖拽完成，也可能由 Shift/方向键完成；只监听
        // leftMouseUp 会漏掉后者。且部分应用在 mouseUp 后才更新 AXSelectedText。
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 先等一轮再读：浏览器等 AX 客户端常在下一轮 runloop 才发布新选区。
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

@MainActor
final class TextActionMenuController {
    static let shared = TextActionMenuController()
    private var alert: NSAlert?
    private var translationProvider: (any LLMManaging)?

    func configure(translationProvider: any LLMManaging) { self.translationProvider = translationProvider }
    func show(text: String, at _: CGPoint) {
        hide()
        let alert = NSAlert()
        alert.messageText = "Text Actions"
        alert.informativeText = text
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Search")
        alert.addButton(withTitle: "Cancel")
        self.alert = alert
        let response = alert.runModal()
        defer { self.alert = nil }
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        if response == .alertSecondButtonReturn,
           var components = URLComponents(string: "https://www.google.com/search") {
            components.queryItems = [URLQueryItem(name: "q", value: text)]
            if let url = components.url { NSWorkspace.shared.open(url) }
        }
    }

    func hide() { alert?.window.orderOut(nil); alert = nil }
}

/// 文本操作设置页。
///
/// 布局遵循 settings-ui 规范：`PluginSettingsScaffold` + `AppSettingSection` +
/// `AppSettingRow`，不使用原生 `Form`——否则这一页会和其他设置入口
/// 呈现完全不同的原生分组样式，间距也对不齐。
struct TextActionsSettingsView: View {
    @State private var enabled = TextActionsSettings.isEnabled

    var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Text Actions"),
            subtitle: pluginLocalization.string(
                "Show copy, search, and translation actions for selected text in other macOS apps."
            ),
            showHeader: false
        ) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(
                    title: pluginLocalization.string("General"),
                    titleAlignment: .leading
                ) {
                    VStack(spacing: 0) {
                        AppSettingToggleRow(
                            pluginLocalization.string("Enable selected-text actions"),
                            isOn: Binding(
                                get: { enabled },
                                set: { newValue in
                                    enabled = newValue
                                    TextActionsSettings.setEnabled(newValue)
                                }
                            )
                        )

                        Divider()
                            .padding(.vertical, 8)

                        AppSettingRow(
                            title: pluginLocalization.string("Accessibility Permission")
                        ) {
                            AppButton(
                                pluginLocalization.string("Request Accessibility Permission"),
                                style: .secondary,
                                size: .small
                            ) {
                                TextSelectionManager.shared.requestPermission()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
