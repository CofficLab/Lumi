import SwiftUI
import os
import LumiCoreKit

actor HostsManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = true

    static let id = "HostsManager"
    static let navigationId = "hosts_manager"
    static let displayName = String(localized: "Hosts Manager", table: "HostsManager")
    static let description = String(localized: "Manage system hosts file configuration", table: "HostsManager")
    static let iconName = "list.bullet.rectangle"
    static var category: PluginCategory { .system }
    static var order: Int { 21 }

    nonisolated static let policy: PluginPolicy = .optIn
    
    /// 插件注册策略：可配置，默认不启用（可选功能）

    nonisolated var instanceLabel: String { Self.id }

    static let shared = HostsManagerPlugin()

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Hosts 文件管理",
                subtitle: "编辑和维护系统 hosts 配置，适合本地调试与域名映射。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("127.0.0.1", "映射"),
                    PluginPosterSupport.metric("DNS", "解析"),
                ],
                rows: ["Hosts 条目", "启用状态", "系统文件写入"],
                chips: ["系统", "DNS", "配置"]
            ),
        ]
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(HostsManagerView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
