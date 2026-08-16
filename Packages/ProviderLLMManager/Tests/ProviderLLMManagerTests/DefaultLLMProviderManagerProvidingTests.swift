import Foundation
import ProviderLLM
import ProviderMessage
import Testing
@testable import ProviderLLMManager

@MainActor
struct DefaultLLMProviderManagerProvidingTests {

    private func makeMessage(_ content: String) -> Message {
        Message(conversationID: UUID(), role: .user, content: content)
    }

    // MARK: - Registration

    @Test("注册保持插入顺序，重复注册覆盖并保持原位置")
    func registerPreservesOrderAndReplaces() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "b"))
        try manager.register(MockManagedProvider(id: "a"))
        try manager.register(MockManagedProvider(id: "a", displayName: "new"))

        #expect(manager.allProviders().map(\.providerInfo.id) == ["b", "a"])
        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "a")?.providerInfo.displayName == "new")
    }

    @Test("注册空 id 抛 emptyProviderID")
    func registerEmptyIDThrows() {
        let manager = DefaultLLMProviderManagerProviding()
        #expect(throws: LLMProviderManagerError.emptyProviderID) {
            try manager.register(MockManagedProvider(id: ""))
        }
        #expect(manager.providerCount == 0)
    }

    @Test("注销后不可再查到，注销选中项回退到第一个供应商")
    func unregisterFallsBackSelection() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "a"))
        try manager.register(MockManagedProvider(id: "b"))
        manager.select(providerID: "b", model: nil)

        #expect(manager.selectedProviderID == "b")
        manager.unregister(id: "b")

        #expect(manager.provider(id: "b") == nil)
        #expect(manager.providerCount == 1)
        #expect(manager.selectedProviderID == "a")
    }

    @Test("注销不存在的 id 无副作用")
    func unregisterUnknownIsNoop() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "a"))
        manager.unregister(id: "missing")
        #expect(manager.providerCount == 1)
    }

    // MARK: - Selection

    @Test("首次注册自动选中第一个供应商并落到默认模型")
    func firstRegistrationSelectsDefault() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "a", models: ["m1", "m2"], defaultModel: "m2"))

        #expect(manager.selectedProviderID == "a")
        #expect(manager.selectedModel == "m2")
    }

    @Test("select 切换供应商与模型，并校验模型归属")
    func selectSwitchesProviderAndModel() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "a", models: ["a1"]))
        try manager.register(MockManagedProvider(id: "b", models: ["b1"], defaultModel: "b1"))

        manager.select(providerID: "b", model: "b1")
        #expect(manager.selectedProviderID == "b")
        #expect(manager.selectedModel == "b1")
        #expect(manager.models(for: "b") == ["b1"])

        // 不存在的供应商被静默忽略。
        manager.select(providerID: "missing", model: "x")
        #expect(manager.selectedProviderID == "b")
    }

    @Test("选中模型不属于当前供应商时，发送回退默认模型")
    func staleSelectedModelFallsBackToDefault() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let a = MockManagedProvider(id: "a", models: ["a1", "a2"], defaultModel: "a1")
        try manager.register(a)

        manager.select(providerID: "a", model: "stale-not-exist")
        let response = try await manager.complete(
            LLMRequest(conversationID: UUID(), messages: [makeMessage("hi")])
        )

        #expect(response.content == "mock:hi")
        #expect(a.receivedModels == ["a1"])
    }

    // MARK: - Send routing

    @Test("complete 路由到选中供应商并补充解析出的模型")
    func completeRoutesToSelectedProvider() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let a = MockManagedProvider(id: "a", prefix: "A")
        let b = MockManagedProvider(id: "b", models: ["b1"], defaultModel: "b1", prefix: "B")
        try manager.register(a)
        try manager.register(b)

        manager.select(providerID: "b", model: nil)
        let response = try await manager.complete(
            LLMRequest(conversationID: UUID(), messages: [makeMessage("ping")])
        )

        #expect(response.content == "B:ping")
        #expect(response.model == "b1")
        #expect(a.receivedModels.isEmpty)
        #expect(b.receivedModels == ["b1"])
    }

    @Test("请求自带模型时优先使用，不覆盖选中模型")
    func completePrefersRequestModel() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let a = MockManagedProvider(id: "a", models: ["a1", "a2"], defaultModel: "a1", prefix: "A")
        try manager.register(a)

        let response = try await manager.complete(
            LLMRequest(
                conversationID: UUID(),
                messages: [makeMessage("hi")],
                model: "a2"
            )
        )

        #expect(response.model == "a2")
        #expect(a.receivedModels == ["a2"])
    }

    @Test("无供应商时 complete 抛 noProviderConfigured")
    func completeWithoutProvidersThrows() async {
        let manager = DefaultLLMProviderManagerProviding()
        await #expect(throws: LLMProviderManagerError.noProviderConfigured) {
            _ = try await manager.complete(
                LLMRequest(conversationID: UUID(), messages: [makeMessage("hi")])
            )
        }
    }

    @Test("complete 不改变持久化选中态（纯读取）")
    func completeDoesNotMutateSelection() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockManagedProvider(id: "a", models: ["a1"], defaultModel: "a1"))
        manager.select(providerID: "a", model: "a1")

        _ = try await manager.complete(
            LLMRequest(conversationID: UUID(), messages: [makeMessage("hi")])
        )

        #expect(manager.selectedProviderID == "a")
        #expect(manager.selectedModel == "a1")
    }

    // MARK: - LLMProviding identity

    @Test("管理器作为 LLMProviding 的身份标识稳定")
    func managerIdentityIsStable() {
        let manager = DefaultLLMProviderManagerProviding()
        #expect(manager.providerID == "llm-provider-manager")
        #expect(manager.providerID == DefaultLLMProviderManagerProviding.managerProviderID)
    }
}
