import AgentToolKit
import LumiCoreKit
import PluginAppStoreConnect
import SwiftUI
import os

actor AppStoreConnectPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect")

    nonisolated static let emoji = ""
    nonisolated static let verbose: Bool = PluginAppStoreConnect.AppStoreConnectPlugin.verbose

    static let id = PluginAppStoreConnect.AppStoreConnectPlugin.id
    static let navigationId = PluginAppStoreConnect.AppStoreConnectPlugin.navigationId
    static let displayName = PluginAppStoreConnect.AppStoreConnectPlugin.displayName
    static let description = PluginAppStoreConnect.AppStoreConnectPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginAppStoreConnect.AppStoreConnectPlugin.description(for: language)
    }
    static let iconName = PluginAppStoreConnect.AppStoreConnectPlugin.iconName
    static var category: PluginCategory { .developerTool }
    static var order: Int { PluginAppStoreConnect.AppStoreConnectPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppStoreConnectPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "App Store Connect",
                subtitle: "在 Lumi 内查看 App Store Connect 应用、版本和发布相关信息。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("ASC", "接口"),
                    PluginPosterSupport.metric("Apps", "应用"),
                ],
                rows: ["凭证配置", "应用列表", "版本状态"],
                chips: ["Apple", "发布", "开发者"]
            ),
        ]
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginAppStoreConnect.AppStoreConnectPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }

    @MainActor
    func addToolBarCenterView(context: PluginContext) -> AnyView? {
        PluginAppStoreConnect.AppStoreConnectPlugin.shared.addToolBarCenterView(context: context)
    }
}
