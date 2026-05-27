import Foundation
import PluginAppIconDesigner
import SwiftUI
import os

actor AppIconDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-icon-designer")

    nonisolated static let emoji = "🎨"
    nonisolated static let verbose = true
    nonisolated static let enable = PluginAppIconDesigner.AppIconDesignerPlugin.enable

    static let id = PluginAppIconDesigner.AppIconDesignerPlugin.id
    static let displayName = PluginAppIconDesigner.AppIconDesignerPlugin.displayName
    static let description = PluginAppIconDesigner.AppIconDesignerPlugin.description
    static let iconName = PluginAppIconDesigner.AppIconDesignerPlugin.iconName
    static let isConfigurable = PluginAppIconDesigner.AppIconDesignerPlugin.isConfigurable
    static var category: PluginCategory { .general }
    static var order: Int { PluginAppIconDesigner.AppIconDesignerPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = AppIconDesignerPlugin()

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t) registered")
        }
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(PluginAppIconDesigner.AppIconDesignerView())
        }
    }
}
