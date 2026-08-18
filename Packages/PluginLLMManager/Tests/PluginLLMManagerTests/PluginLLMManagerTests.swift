import Foundation
import KernelCore
import ProviderConversation
import ProviderLLMManager
import KitLLM
import ProviderMessage
import ProviderMessageRendering
import Testing
@testable import PluginLLMManager

@MainActor
@Suite("PluginLLMManager")
struct PluginLLMManagerTests {

    /// onBoot 应替换 ProviderFactory 预注册的默认管理器，并注册本插件的实现。
    @Test("onBoot 替换默认 LLMManaging 为 CustomLLMManager")
    func onBootReplacesDefaultManager() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())

        let plugin = PluginLLMManager()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any LLMManaging).self)
        #expect(resolved is CustomLLMManager)
    }

    /// onBoot 应把 API Key 缺失 / 读取失败两个渲染器注册进 MessageRenderingProviding。
    @Test("onBoot 注册 API Key 消息渲染器")
    func onBootRegistersAPIKeyRenderers() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider((any MessageRenderingProviding).self, DefaultMessageRenderingProviding())

        let plugin = PluginLLMManager()
        try plugin.onBoot(kernel: kernel)

        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        let ids = rendering?.allRenderers.map(\.id) ?? []
        #expect(ids.contains(LLMProviderAPIKeyMessage.missingRenderKind))
        #expect(ids.contains(LLMProviderAPIKeyMessage.accessFailedRenderKind))
        // Key 渲染器必须优先于 core-error-message(order=300)。
        let missing = rendering?.allRenderers.first { $0.id == LLMProviderAPIKeyMessage.missingRenderKind }
        #expect((missing?.order ?? 0) > 300)
    }

    /// 自研管理器转发注册/选中/路由：注册一个回显供应商后，
    /// complete 应命中该供应商并返回内容。
    @Test("CustomLLMManager 转发注册与路由")
    func customManagerRoutesToRegisteredProvider() async throws {
        let manager = CustomLLMManager()
        let provider = EchoProvider()
        try manager.register(provider)
        manager.select(providerID: provider.providerInfo.id, model: nil)

        #expect(manager.providerCount == 1)
        #expect(manager.selectedProviderID == provider.providerInfo.id)

        let response = try await manager.complete(LLMRequest(
            conversationID: UUID(),
            messages: [LLMMessage(role: .user, content: "ping")]
        ))
        #expect(response.content == "ping")
    }

    /// 路由扩展点：routingOverride 优先于引擎默认路由。
    @Test("routingOverride 优先路由")
    func routingOverrideTakesPrecedence() async throws {
        let manager = CustomLLMManager()
        let provider = EchoProvider()
        try manager.register(provider)

        var usedOverride = false
        manager.routingOverride = { _ in
            usedOverride = true
            return (provider, nil)
        }

        _ = try await manager.complete(LLMRequest(
            conversationID: UUID(),
            messages: [LLMMessage(role: .user, content: "ping")]
        ))
        #expect(usedOverride)
    }

    /// 切换当前对话时,插件应把会话绑定的供应商/模型同步到 LLMManaging 选中值。
    @Test("切换对话同步会话绑定的供应商/模型到选中")
    func switchingConversationSyncsSelection() throws {
        let kernel = KernelCoreContainer()
        // LLMManaging 由 plugin.onBoot 注册,这里不预注册,避免与插件内部实例分叉。
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        let plugin = PluginLLMManager()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        // 从内核取出插件注册的 manager,并注册供应商(select 才会生效)。
        let manager = try #require(kernel.resolveProvider((any LLMManaging).self))
        try manager.register(EchoProvider(id: "deepseek"))

        // 顶层对话创建后自动选中 → didSet 触发 observer → 同步选中。
        let id = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: "deepseek",
            modelName: "deepseek-v4-flash"
        )
        #expect(conversations.selectedConversationID == id)
        #expect(manager.selectedProviderID == "deepseek")
        #expect(manager.selectedModel == "deepseek-v4-flash")
    }

    /// 测试用最小 LLM 供应商：回显最后一条用户消息。
    @MainActor
    private final class EchoProvider: ManagedLLMProvider, @preconcurrency LLMProviding {
        let providerInfo: LLMProviderInfo
        var providerID: String { providerInfo.id }

        init(id: String = "echo") {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: "Echo",
                defaultModel: "echo-1",
                models: [LLMModelInfo(id: "echo-1")]
            )
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            let content = request.messages.compactMap(\.content).last ?? ""
            return LLMResponse(content: content, model: "echo-1")
        }
    }
}
