import MagicKit
import SwiftUI

/// DevAssistant 输入插件 - 负责显示输入区域（编辑器、工具栏等）
actor DevAssistantInputPlugin: SuperPlugin {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose = false

    static let id = "DevAssistantInput"
    static let displayName = String(localized: "Dev Assistant Input", table: "DevAssistant")
    static let description = String(localized: "DevAssistant input area", table: "DevAssistant")
    static let iconName = "textformat.abc"
    static var order: Int { 83 }

    static let shared = DevAssistantInputPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // Init
    }

    nonisolated func onDisable() {
        // Cleanup
    }

    // MARK: - UI

    @MainActor
    func addSettingsView() -> AnyView? {
        return AnyView(DevAssistantSettingsView())
    }

    @MainActor
    func addDetailBottomView() -> AnyView? {
        return AnyView(DevAssistantInputView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation("dev_assistant")
        .inRootView()
        .withDebugBar()
}
