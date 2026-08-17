import Foundation
import KernelCore
import ProviderLLMManager
import ProviderLLMVendors
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
            messages: [Message(conversationID: UUID(), role: .user, content: "ping")]
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
            messages: [Message(conversationID: UUID(), role: .user, content: "ping")]
        ))
        #expect(usedOverride)
    }

    /// 测试用最小 LLM 供应商：回显最后一条用户消息。
    @MainActor
    private final class EchoProvider: ManagedLLMProvider, @preconcurrency LLMProviding {
        let providerInfo: LLMProviderInfo

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
