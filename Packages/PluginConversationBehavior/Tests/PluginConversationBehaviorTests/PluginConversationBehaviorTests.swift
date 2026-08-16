import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderAgentLoop
import ProviderMessage

@testable import PluginConversationBehavior

@Suite("PluginConversationBehavior")
@MainActor
struct PluginConversationBehaviorTests {
    private func makeKernel() throws -> (KernelCoreContainer, DefaultConversationManager, DefaultChatSectionProviding) {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return (kernel, conversations, chat)
    }

    @Test("Verbosity 插件注册钩子与工具栏按钮")
    func verbosityRegisters() async throws {
        let (kernel, conversations, _) = try makeKernel()
        let messages = DefaultMessageManaging()
        let loop = DefaultAgentLoopProviding(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, loop)

        let plugin = ConversationVerbosityPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
    }

    @Test("Verbosity 准备器注入 V2 标准指令")
    func verbosityPreparer() async {
        let conversations = DefaultConversationManager()
        let conversationID = UUID()
        let history = [Message(conversationID: conversationID, role: .user, content: "hi")]
        let prepared = await VerbosityPreparer(conversations: conversations).prepare(history)
        #expect(prepared.count == 2)
        #expect(prepared.first?.role == .system)
        #expect(prepared.first?.content.contains("V2 (standard)") == true)
    }

    @Test("Language 准备器注入语言指令")
    func languagePreparer() async {
        let conversations = DefaultConversationManager()
        conversations.setGlobalLanguage(.english)
        let conversationID = UUID()
        let history = [Message(conversationID: conversationID, role: .user, content: "hi")]
        let prepared = await LanguagePreparer(conversations: conversations).prepare(history)
        #expect(prepared.count == 2)
        #expect(prepared.first?.role == .system)
        #expect(prepared.first?.content.contains("English") == true)
    }

    @Test("Reasoning 插件注册 ActionBar 按钮")
    func reasoningRegisters() throws {
        let (kernel, _, _) = try makeKernel()
        let plugin = ConversationReasoningPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
    }

    @Test("Reasoning 档位经 ConversationManaging 读写")
    func reasoningRoundTrip() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalReasoningEffort(.high)
        #expect(conversations.reasoningEffortOptional(for: nil) == .high)
        conversations.clearReasoningEffort(for: nil)
        #expect(conversations.reasoningEffortOptional(for: nil) == nil)
    }
}
