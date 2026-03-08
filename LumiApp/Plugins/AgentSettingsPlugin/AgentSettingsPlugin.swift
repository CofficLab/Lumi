import MagicKit
import SwiftUI

/// Agent 设置插件 - 负责显示开发助手的设置界面
actor AgentSettingsPlugin: SuperPlugin {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    static let id = "AgentSettings"
    static let displayName = String(localized: "Agent Settings", table: "DevAssistant")
    static let description = String(localized: "Agent settings and configuration", table: "DevAssistant")
    static let iconName = "gear"
    static var order: Int { 82 }
    nonisolated static let enable = true

    static let shared = AgentSettingsPlugin()

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
        return AnyView(AgentSettingsView())
    }
}
