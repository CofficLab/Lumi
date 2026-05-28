import AgentToolKit
import PluginBrewManager
import SwiftUI
import os

actor BrewManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")

    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🍺"
    nonisolated static let verbose: Bool = PluginBrewManager.BrewManagerPlugin.verbose

    static let id = PluginBrewManager.BrewManagerPlugin.id
    static let navigationId = PluginBrewManager.BrewManagerPlugin.navigationId
    static let displayName = PluginBrewManager.BrewManagerPlugin.displayName
    static let description = PluginBrewManager.BrewManagerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginBrewManager.BrewManagerPlugin.description(for: language)
    }
    static let iconName = PluginBrewManager.BrewManagerPlugin.iconName
    static var category: PluginCategory { .developerTool }
    static var order: Int { 60 }
    nonisolated static let policy: PluginPolicy = .optIn
    nonisolated var instanceLabel: String { Self.id }
    static let shared = BrewManagerPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Homebrew 管理",
                subtitle: "集中查看 formula、cask、过期包和常用维护操作。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric("brew", "命令"),
                    PluginPosterSupport.metric("Cask", "应用包"),
                ],
                rows: ["已安装包", "可更新项目", "维护操作"],
                chips: ["开发工具", "包管理", "更新"]
            ),
        ]
    }
    
    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginBrewManager.BrewManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
