import Testing
import LumiCoreKit
@testable import ConversationTitlePlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationTitlePlugin.policy == .alwaysOn)
    #expect(ConversationTitlePlugin.isConfigurable == false)
}

@MainActor
@Test func pluginRegistersTitleMiddleware() {
    let middlewareIds = ConversationTitlePlugin.shared.sendMiddlewares().map(\.id)

    #expect(middlewareIds.contains("auto.conversation.title"))
    #expect(middlewareIds.contains("conversation-title-hint"))
}

@MainActor
@Test func pluginRegistersTitleToolWhenConversationContextExists() {
    let conversationListContext = ConversationListContext()
    let context = ToolContext(conversationListContext: conversationListContext)
    let tools = ConversationTitlePlugin.shared.agentTools(context: context)

    #expect(tools.map(\.name).contains("update_conversation_title"))
}
