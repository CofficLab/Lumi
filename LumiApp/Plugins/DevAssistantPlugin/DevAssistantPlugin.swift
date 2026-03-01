import MagicKit
import SwiftUI

actor DevAssistantPlugin: SuperPlugin {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    static let id = "DevAssistant"
    static let navigationId = "dev_assistant"
    static let displayName = String(localized: "Dev Assistant", table: "DevAssistant")
    static let description = String(localized: "Agentic coding assistant", table: "DevAssistant")
    static let iconName = "terminal.fill"
    static var order: Int { 80 }

    static let shared = DevAssistantPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // 初始化供应商注册表
        Task {
            await ProviderRegistry.shared.registerAllProviders()
        }
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
    func addDetailView() -> AnyView? {
        // 在 Agent 模式下提供 DevAssistantView 作为详情视图
        return AnyView(DevAssistantView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
