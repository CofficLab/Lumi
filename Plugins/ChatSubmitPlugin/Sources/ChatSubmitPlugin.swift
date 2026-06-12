import LumiCoreKit
import LumiUI
import SwiftUI
import SuperLogKit
import os

public actor ChatSubmitPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-submit")
    public nonisolated static let emoji = "🚀"
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let verbose: Bool = false

    public static let id = "ChatSubmit"
    public static let displayName = LumiPluginLocalization.string("Chat Submit", bundle: .module)
    public static let description = LumiPluginLocalization.string("Send or stop chat messages", bundle: .module)
    public static let iconName = "paperplane"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 86 }
    public static let shared = ChatSubmitPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    @MainActor
    public func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat.isVisible else { return [] }
        return [
            SidebarToolbarItem(
                id: "chat-submit",
                title: LumiPluginLocalization.string("Send Message", bundle: .module),
                systemImage: "paperplane.fill",
                priority: 50
            )
        ]
    }

    @MainActor
    public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "chat-submit" else { return nil }
        guard let chatSubmitContext = context.chatSubmitContext else { return nil }
        return AnyView(ChatSubmitToolbarButton(submitContext: chatSubmitContext))
    }
}
