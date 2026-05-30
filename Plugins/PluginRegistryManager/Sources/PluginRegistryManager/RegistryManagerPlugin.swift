import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import Foundation

public actor RegistryManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🔁"
    public nonisolated static let verbose: Bool = true

    public static let id = "RegistryManager"
    public static let navigationId: String = "registry_manager"
    public static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    public static let description = String(localized: "Manage Lumi registries", table: "RegistryManager")
    public static let iconName = "arrow.triangle.2.circlepath"
    public static var category: PluginCategory { .system }
    public static var order: Int { 80 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = RegistryManagerPlugin()

    // MARK: - UI

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
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
