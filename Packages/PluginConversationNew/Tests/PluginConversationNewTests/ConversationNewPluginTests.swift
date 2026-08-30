import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderToolbar
import Testing
@testable import PluginConversationNew

@MainActor
struct ConversationNewPluginTests {
    @Test("只有 ChatSection 可见且存在选中会话时才显示新建按钮")
    func showsNewChatButtonOnlyForSelectedConversation() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        let toolbar = DefaultToolbarProviding()

        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = ConversationNewPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(conversations.selectedConversationID == nil)
        #expect(toolbar.toolbarItems.isEmpty)

        let conversationID = try conversations.createConversation(
            title: "Test conversation",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        conversations.selectConversation(id: conversationID)
        #expect(toolbar.toolbarItems.map(\.id) == ["com.coffic.lumi.plugin.conversation-new.new-chat"])

        chat.setVisible(false)
        #expect(toolbar.toolbarItems.isEmpty)

        chat.setVisible(true)
        #expect(toolbar.toolbarItems.map(\.id) == ["com.coffic.lumi.plugin.conversation-new.new-chat"])

        try plugin.onShutdown(kernel: kernel)
    }
}
