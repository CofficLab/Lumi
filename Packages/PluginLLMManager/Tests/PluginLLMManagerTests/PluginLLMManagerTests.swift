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

    @Test("旧版 missingAPIKey 文本消息也能命中 API Key 渲染器")
    func legacyMissingAPIKeyMessageMatchesRenderer() {
        let message = Message(
            conversationID: UUID(),
            role: .error,
            content: "missingAPIKey(\"OpenCode Go\")"
        )

        #expect(LLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message))
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
        #expect(response.content == "echo:ping")
    }

    @Test("请求显式供应商时不会被 CustomLLMManager 的全局选择覆盖")
    func customManagerRoutesToExplicitProvider() async throws {
        let manager = CustomLLMManager()
        let global = EchoProvider(id: "global", model: "global-model")
        let conversation = EchoProvider(id: "conversation", model: "conversation-model")
        try manager.register(global)
        try manager.register(conversation)
        manager.select(providerID: "global", model: "global-model")

        let response = try await manager.streamComplete(
            LLMRequest(
                conversationID: UUID(),
                providerID: "conversation",
                messages: [LLMMessage(role: .user, content: "ping")],
                model: "conversation-model"
            ),
            onChunk: { _ in }
        )

        #expect(response.content == "conversation:ping")
        #expect(global.receivedModels.isEmpty)
        #expect(conversation.receivedModels == ["conversation-model"])
        #expect(manager.selectedProviderID == "global")
        #expect(manager.selectedModel == "global-model")
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

    /// 对话绑定通过请求显式路由，不应覆盖全局供应商/模型选择。
    @Test("切换对话不会改写全局供应商/模型选择")
    func switchingConversationDoesNotMutateGlobalSelection() throws {
        let kernel = KernelCoreContainer()
        // LLMManaging 由 plugin.onBoot 注册,这里不预注册,避免与插件内部实例分叉。
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        let plugin = PluginLLMManager()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        // 从内核取出插件注册的 manager,并注册全局与对话供应商。
        let manager = try #require(kernel.resolveProvider((any LLMManaging).self))
        try manager.register(EchoProvider(id: "global"))
        try manager.register(EchoProvider(id: "conversation"))
        manager.select(providerID: "global", model: "echo-1")

        // 顶层对话创建后自动选中，但不能改写全局选择。
        let id = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: "conversation",
            modelName: "echo-1"
        )
        #expect(conversations.selectedConversationID == id)
        #expect(manager.selectedProviderID == "global")
        #expect(manager.selectedModel == "echo-1")
    }

    @Test("onboarding 供应商选择器仅包含云服务商")
    func onboardingProviderSelectionFiltersRelaysAndLocalProviders() throws {
        let cloud = EchoProvider(id: "cloud", model: "cloud-model", providerType: .cloudService)
        let relay = EchoProvider(id: "relay", model: "relay-model", providerType: .relay)
        let local = EchoProvider(id: "local", model: "local-model", providerType: .local, isLocal: true)

        let manager = DefaultLLMManager()
        try manager.register(cloud)
        try manager.register(relay)
        try manager.register(local)
        let viewModel = AISetupViewModel(
            capability: LLMManagerCapabilityAdapter(manager: manager),
            customProviderStore: nil
        )

        #expect(viewModel.providers.map(\.providerID) == ["cloud"])
    }

    /// 测试用最小 LLM 供应商：回显最后一条用户消息。
    @MainActor
    private final class EchoProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        var providerID: String { providerInfo.id }

        private(set) var receivedModels: [String] = []

        init(
            id: String = "echo",
            model: String = "echo-1",
            providerType: LLMProviderType = .cloudService,
            isLocal: Bool = false
        ) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: "Echo",
                defaultModel: model,
                models: [LLMModelInfo(id: model)],
                isLocal: isLocal,
                providerType: providerType
            )
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            receivedModels.append(request.model ?? "")
            let content = request.messages.compactMap(\.content).last ?? ""
            return LLMResponse(content: "\(providerInfo.id):\(content)", model: request.model)
        }
    }
}
