import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation

@testable import PluginConversationMode

@Suite("ConversationModePlugin")
@MainActor
struct ConversationModePluginTests {
    @Test("插件 onBoot/onShutdown 不抛错且 Provider 保持可用")
    func pluginLifecycle() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        let plugin = ConversationModePlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
        #expect(kernel.resolveProvider((any ChatSectionProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider((any ChatSectionProviding).self) != nil)
    }

    @Test("全局自动化级别通过 ConversationManaging 读写")
    func automationLevelRoundTrip() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalAutomationLevel(.autonomous)
        #expect(conversations.globalAutomationLevel == .autonomous)
        #expect(conversations.automationLevel(for: nil) == .autonomous)
    }
}
