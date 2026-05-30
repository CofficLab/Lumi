import PluginChatMode
import SwiftUI

actor ChatModePlugin: SuperPlugin {
    nonisolated static let logger = PluginChatMode.ChatModePlugin.logger
    nonisolated static let emoji = PluginChatMode.ChatModePlugin.emoji
    nonisolated static let verbose = PluginChatMode.ChatModePlugin.verbose
    static let id = PluginChatMode.ChatModePlugin.id
    static let displayName = PluginChatMode.ChatModePlugin.displayName
    static let description = PluginChatMode.ChatModePlugin.description
    static let iconName = PluginChatMode.ChatModePlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatMode.ChatModePlugin.category) }
    static var order: Int { PluginChatMode.ChatModePlugin.order }
    static let shared = ChatModePlugin()

    private let packaged = PluginChatMode.ChatModePlugin.shared

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        packaged.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "chat-mode-toggle" else { return nil }
        return AnyView(ChatModeRuntimeBridge())
    }
}

@MainActor
private struct ChatModeRuntimeBridge: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    var body: some View {
        PluginChatMode.ChatModeToolbarButton()
            .onAppear(perform: sync)
            .onChange(of: llmVM.chatMode) { _, _ in sync() }
    }

    private func sync() {
        PluginChatMode.ChatModeRuntime.modeProvider = { map(llmVM.chatMode) }
        PluginChatMode.ChatModeRuntime.setMode = { mode in
            let appMode = map(mode)
            llmVM.setChatMode(appMode)
            conversationVM.saveChatModePreference(appMode)
        }
    }

    private func map(_ mode: ChatMode) -> PluginChatMode.ChatModeValue {
        switch mode {
        case .chat: return .chat
        case .build: return .build
        case .autonomous: return .autonomous
        }
    }

    private func map(_ mode: PluginChatMode.ChatModeValue) -> ChatMode {
        switch mode {
        case .chat: return .chat
        case .build: return .build
        case .autonomous: return .autonomous
        }
    }
}
