import PluginChatPanel
import SwiftUI

actor ChatPanelPlugin: SuperPlugin {
    nonisolated static let logger = PluginChatPanel.ChatPanelPlugin.logger
    nonisolated static let emoji = PluginChatPanel.ChatPanelPlugin.emoji
    nonisolated static let verbose = PluginChatPanel.ChatPanelPlugin.verbose
    nonisolated static let policy = PluginChatPanel.ChatPanelPlugin.policy
    static let id = PluginChatPanel.ChatPanelPlugin.id
    static let displayName = PluginChatPanel.ChatPanelPlugin.displayName
    static let description = PluginChatPanel.ChatPanelPlugin.description
    static let iconName = PluginChatPanel.ChatPanelPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatPanel.ChatPanelPlugin.category) }
    static var order: Int { PluginChatPanel.ChatPanelPlugin.order }
    static let shared = ChatPanelPlugin()

    private let packaged = PluginChatPanel.ChatPanelPlugin.shared

    @MainActor
    func addPosterViews() -> [AnyView] {
        packaged.addPosterViews()
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        packaged.addViewContainer().map(ViewContainerItem.init(package:))
    }
}
