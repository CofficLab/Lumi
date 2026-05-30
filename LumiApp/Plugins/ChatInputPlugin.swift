import PluginChatInput
import SwiftUI

actor ChatInputPlugin: SuperPlugin {
    nonisolated static let logger = PluginChatInput.ChatInputPlugin.logger
    nonisolated static let emoji = PluginChatInput.ChatInputPlugin.emoji
    nonisolated static let verbose = PluginChatInput.ChatInputPlugin.verbose
    static let id = PluginChatInput.ChatInputPlugin.id
    static let displayName = PluginChatInput.ChatInputPlugin.displayName
    static let description = PluginChatInput.ChatInputPlugin.description
    static let iconName = PluginChatInput.ChatInputPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatInput.ChatInputPlugin.category) }
    static var order: Int { PluginChatInput.ChatInputPlugin.order }
    static let shared = ChatInputPlugin()

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(ChatInputRuntimeBridge())]
    }
}

@MainActor
private struct ChatInputRuntimeBridge: View {
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        PluginChatInput.InputView()
            .onAppear(perform: sync)
            .onChange(of: conversationVM.selectedConversationId) { _, _ in sync() }
    }

    private func sync() {
        PluginChatInput.ChatInputRuntime.canChatProvider = {
            conversationVM.selectedConversationId != nil
        }
        PluginChatInput.ChatInputRuntime.submitText = { text in
            if conversationVM.selectedConversationId == nil {
                await conversationVM.createNewConversation(
                    projectName: projectVM.isProjectSelected ? projectVM.currentProjectName : nil,
                    projectPath: projectVM.isProjectSelected ? projectVM.currentProjectPath : nil,
                    languagePreference: projectVM.languagePreference
                )
            }
            inputQueueVM.enqueueText(text)
        }
    }
}
