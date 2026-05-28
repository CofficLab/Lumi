import SwiftUI
import os

actor NettoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    nonisolated static let emoji = "🛡️"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = true

    static let id = "Netto"
    static let navigationId = "netto_firewall"
    static let displayName = String(localized: "Netto Firewall", table: "Netto")
    static let description = String(localized: "Manage network permissions for macOS applications.", table: "Netto")
    static let iconName = "shield.lefthalf.filled"
    static var order: Int { 99 }

    nonisolated static let policy: PluginPolicy = .optIn
    
    /// 插件注册策略：可配置，默认不启用（可选功能）
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = NettoPlugin()
    
    // MARK: - UI Contributions

    

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(NettoDashboardView())
        }
    }
}
