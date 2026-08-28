import FactoryLumi
import KernelCore
import PluginConversationManager
import ProviderConversation
import Testing

/// 验证 ConversationManagerPlugin 在 FactoryLumi 装配中
/// 替代默认的内存版 `DefaultConversationManaging`。
@Suite("ConversationManagerPlugin Replacement")
@MainActor
struct ConversationManagerReplacementTests {
    @Test("插件注册且 ConversationManaging 被替换为 SwiftData 实现")
    func replacesDefaultConversationManaging() throws {
        let kernel = try KernelFactory.makeKernel()

        // 插件本身已注册（order=7，早于消费方 ConversationListPlugin order=81）。
        #expect(kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.conversation-store"))

        // ConversationManaging 不再是最初的内存实现，而是 SwiftData 的 ConversationManager。
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        #expect(conversations != nil)
        #expect(conversations is ConversationManager)
    }

    @Test("替换后消费方可解析并使用持久化实现")
    func resolvedProviderIsUsable() throws {
        let kernel = try KernelFactory.makeKernel()
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Issue.record("ConversationManaging 未注册")
            return
        }

        // 不创建对话（避免污染真实用户数据），只验证协议可正常调用。
        #expect(conversations.conversations.isEmpty)
        #expect(conversations.currentTitle == "No conversation")
    }
}
