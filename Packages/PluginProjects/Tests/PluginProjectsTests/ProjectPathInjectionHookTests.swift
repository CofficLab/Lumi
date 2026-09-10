import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import Testing
@testable import PluginProjects

@MainActor
@Suite("Project path injection hook")
struct ProjectPathInjectionHookTests {
    @Test("injects the conversation project instead of the currently open project")
    func injectsConversationProject() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Conversation project",
            projectPath: "  /tmp/conversation-project  ",
            providerID: nil,
            modelName: nil
        )
        let hook = ProjectPathInjectionHook(conversations: conversations)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "检查代码")],
            conversationID: conversationID
        )

        let result = await hook.apply(to: context)

        #expect(result.messages.first?.role == .system)
        #expect(result.messages.first?.content == "当前对话项目路径：/tmp/conversation-project")
    }

    @Test("does not inject when the conversation has no project")
    func skipsUnboundConversation() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "No project",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let hook = ProjectPathInjectionHook(conversations: conversations)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "你好")],
            conversationID: conversationID
        )

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
    }
}
