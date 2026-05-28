import SwiftUI
import os

actor RClickPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🖱️"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = true
    
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")

    static let id = "RClick"
    static let navigationId: String? = "rclick"
    static let displayName = String(localized: "Right Click", table: "RClick")
    static let description = String(localized: "Customize Finder right-click menu actions", table: "RClick")
    static let iconName = "cursorarrow.click.2"
    static var order: Int { 50 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RClickPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Finder 右键动作",
                subtitle: "配置文件右键菜单模板，把常用操作放进 Finder。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("Menu", "右键菜单"),
                    PluginPosterSupport.metric("Tpl", "模板"),
                ],
                rows: ["动作模板", "菜单预览", "Finder 集成"],
                chips: ["Finder", "右键", "自动化"]
            ),
        ]
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        Task { @MainActor in
            _ = RClickConfigManager.shared
        }
    }

    // MARK: - UI

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(RClickSettingsView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
