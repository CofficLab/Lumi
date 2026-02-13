import SwiftUI
import MagicKit

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
        // Init services if needed
    }
    
    nonisolated func onDisable() {
        // Cleanup
    }
    
    // MARK: - UI
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DevAssistantView()
            }
        ]
    }
    
    @MainActor
    func addDetailView() -> AnyView? {
        return AnyView(DevAssistantSettingsView())
    }
}
