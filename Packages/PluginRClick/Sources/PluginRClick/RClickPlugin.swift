import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public actor RClickPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🖱️"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true
    
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")

    public static let id = "RClick"
    public static let navigationId: String? = "rclick"
    public static let displayName = String(localized: "Right Click", table: "RClick")
    public static let description = String(localized: "Customize Finder right-click menu actions", table: "RClick")
    public static let iconName = "cursorarrow.click.2"
    public static var order: Int { 50 }
    public nonisolated static let policy: PluginPolicy = .optIn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = RClickPlugin()

    @MainActor
    public func addPosterViews() -> [AnyView] {
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

    public nonisolated func onRegister() {
        Task { @MainActor in
            _ = RClickConfigManager.shared
        }
    }

    // MARK: - UI

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
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
