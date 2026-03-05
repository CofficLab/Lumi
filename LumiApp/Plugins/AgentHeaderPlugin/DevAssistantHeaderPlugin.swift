import MagicKit
import SwiftUI

/// DevAssistant 头部插件 - 负责显示聊天头部（项目信息、工具栏按钮等）
actor DevAssistantHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "📌"
    nonisolated static let verbose = false

    static let id = "DevAssistantHeader"
    static let displayName = String(localized: "Dev Assistant Header", table: "DevAssistant")
    static let description = String(localized: "DevAssistant chat header", table: "DevAssistant")
    static let iconName = "rectangle.topthird.inset.filled"
    static var order: Int { 81 }
    static let enable: Bool = true

    static let shared = DevAssistantHeaderPlugin()

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
    func addDetailHeaderView() -> AnyView? {
        return AnyView(DevAssistantHeaderView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation("dev_assistant")
        .inRootView()
        .withDebugBar()
}
