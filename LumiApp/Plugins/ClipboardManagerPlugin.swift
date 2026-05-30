import PluginClipboardManager
import SwiftUI

actor ClipboardManagerPlugin: SuperPlugin {
    nonisolated static let logger = PluginClipboardManager.ClipboardManagerPlugin.logger
    nonisolated static let emoji = PluginClipboardManager.ClipboardManagerPlugin.emoji
    nonisolated static let verbose = PluginClipboardManager.ClipboardManagerPlugin.verbose
    static let id = PluginClipboardManager.ClipboardManagerPlugin.id
    static let navigationId = PluginClipboardManager.ClipboardManagerPlugin.navigationId
    static let displayName = PluginClipboardManager.ClipboardManagerPlugin.displayName
    static let description = PluginClipboardManager.ClipboardManagerPlugin.description
    static let iconName = PluginClipboardManager.ClipboardManagerPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginClipboardManager.ClipboardManagerPlugin.category) }
    static var order: Int { PluginClipboardManager.ClipboardManagerPlugin.order }
    static let policy = PluginClipboardManager.ClipboardManagerPlugin.policy
    static let shared = ClipboardManagerPlugin()

    nonisolated func onRegister() {
        configureRuntime()
        PluginClipboardManager.ClipboardManagerPlugin.shared.onRegister()
    }

    nonisolated func onEnable() {
        configureRuntime()
        PluginClipboardManager.ClipboardManagerPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginClipboardManager.ClipboardManagerPlugin.shared.onDisable()
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        PluginClipboardManager.ClipboardManagerPlugin.shared.addViewContainer().map(ViewContainerItem.init(package:))
    }

    @MainActor
    func addPosterViews() -> [AnyView] {
        PluginClipboardManager.ClipboardManagerPlugin.shared.addPosterViews()
    }

    private nonisolated func configureRuntime() {
        ClipboardManagerRuntime.databaseDirectoryProvider = {
            AppConfig.getDBFolderURL()
        }
    }
}
