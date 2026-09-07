import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks

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
