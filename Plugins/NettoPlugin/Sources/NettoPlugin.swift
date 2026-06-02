import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public actor NettoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    public nonisolated static let emoji = "🛡️"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id = "Netto"
    public static let navigationId = "netto_firewall"
    public static let displayName = String(localized: "Netto Firewall", table: "Netto")
    public static let description = String(localized: "Manage network permissions for macOS applications.", table: "Netto")
    public static let iconName = "shield.lefthalf.filled"
    public static var order: Int { 99 }

    public nonisolated static let policy: PluginPolicy = .disabled
    
    /// 插件注册策略：可配置，默认不启用（可选功能）
    
    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = NettoPlugin()
    
    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "应用网络权限",
                subtitle: "查看并管理 macOS 应用的网络访问策略。",
                icon: Self.iconName,
                accent: .green,
                metrics: [
                    PluginPosterSupport.metric("Allow", "放行"),
                    PluginPosterSupport.metric("Block", "阻止"),
                ],
                rows: ["应用规则", "网络事件", "权限面板"],
                chips: ["防火墙", "网络", "权限"]
            ),
        ]
    }

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(NettoDashboardView())
        }
    }
}
