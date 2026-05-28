import SwiftUI
import Foundation

actor RegistryManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔁"
    nonisolated static let verbose: Bool = true

    static let id = "RegistryManager"
    static let navigationId: String = "registry_manager"
    static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    static let description = String(localized: "Manage Lumi registries", table: "RegistryManager")
    static let iconName = "arrow.triangle.2.circlepath"
    static var category: PluginCategory { .system }
    static var order: Int { 80 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RegistryManagerPlugin()

    // MARK: - UI

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Lumi 注册表",
                subtitle: "查看和管理 Lumi 内部注册项，帮助诊断扩展点状态。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("Registry", "注册项"),
                    PluginPosterSupport.metric("Debug", "诊断"),
                ],
                rows: ["注册项列表", "扩展点状态", "服务信息"],
                chips: ["系统", "注册表", "诊断"]
            ),
        ]
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(RegistryManagerView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
