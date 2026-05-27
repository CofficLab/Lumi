import LumiCoreKit
import PluginAppStoreConnect
import SwiftUI
import os

actor AppStoreConnectPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect")

    nonisolated static let emoji = ""
    nonisolated static let enable: Bool = PluginAppStoreConnect.AppStoreConnectPlugin.enable
    nonisolated static let verbose: Bool = PluginAppStoreConnect.AppStoreConnectPlugin.verbose

    static let id = PluginAppStoreConnect.AppStoreConnectPlugin.id
    static let navigationId = PluginAppStoreConnect.AppStoreConnectPlugin.navigationId
    static let displayName = PluginAppStoreConnect.AppStoreConnectPlugin.displayName
    static let description = PluginAppStoreConnect.AppStoreConnectPlugin.description
    static let iconName = PluginAppStoreConnect.AppStoreConnectPlugin.iconName
    static let isConfigurable = PluginAppStoreConnect.AppStoreConnectPlugin.isConfigurable
    static var category: PluginCategory { .developerTool }
    static var order: Int { PluginAppStoreConnect.AppStoreConnectPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppStoreConnectPlugin()

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
