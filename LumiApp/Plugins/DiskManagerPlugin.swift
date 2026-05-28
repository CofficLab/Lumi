import AgentToolKit
import PluginDiskManager
import SwiftUI
import os

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💿"
    nonisolated static let verbose: Bool = PluginDiskManager.DiskManagerPlugin.verbose

    static let id = PluginDiskManager.DiskManagerPlugin.id
    static let navigationId = PluginDiskManager.DiskManagerPlugin.navigationId
    static let displayName = PluginDiskManager.DiskManagerPlugin.displayName
    static let description = PluginDiskManager.DiskManagerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginDiskManager.DiskManagerPlugin.description(for: language)
    }
    static let iconName = PluginDiskManager.DiskManagerPlugin.iconName
    static var category: PluginCategory { .system }
    static var order: Int { PluginDiskManager.DiskManagerPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DiskManagerPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "磁盘空间总览",
                subtitle: "快速看清缓存、大文件、Xcode 派生数据和项目占用。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("4", "清理视图"),
                    PluginPosterSupport.metric("Scan", "按需扫描"),
                ],
                rows: ["Xcode DerivedData", "大型文件", "项目构建缓存"],
                chips: ["系统工具", "空间分析", "清理"]
            ),
            PluginPosterSupport.poster(
                title: "按目录定位占用",
                subtitle: "用目录树和分类面板找到真正占空间的位置。",
                icon: "folder.badge.gearshape",
                accent: .cyan,
                rows: ["目录树扫描", "缓存分类", "安全删除确认"],
                chips: ["目录树", "缓存", "Xcode"]
            ),
        ]
    }

    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginDiskManager.DiskManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
