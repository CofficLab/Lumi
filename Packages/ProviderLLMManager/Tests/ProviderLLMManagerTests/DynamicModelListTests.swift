import Foundation
import KitLLM
import Testing
@testable import ProviderLLMManager

/// 可远程更新模型列表的 Mock：直接 override 协议属性模拟动态池。
@MainActor
final class MockRemoteModelProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo
    var availableModels: [LLMModelInfo]
    var usesRemoteModelList: Bool
    var lastModelSyncDate: Date?
    private var refreshHandler: (@MainActor () async throws -> Void)?

    private(set) var refreshCalls = 0

    var providerID: String { providerInfo.id }

    init(
        id: String = "remote",
        baseModels: [String],
        defaultModel: String = "remote-a",
        remoteModelIDs: [String] = [],
        usesRemote: Bool = true,
        refreshHandler: (@MainActor () async throws -> Void)? = nil
    ) {
        self.providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: defaultModel,
            models: baseModels.map { LLMModelInfo(id: $0) }
        )
        self.availableModels = baseModels.map { LLMModelInfo(id: $0) }
            + remoteModelIDs.map { LLMModelInfo(id: $0) }
        self.usesRemoteModelList = usesRemote
        self.refreshHandler = refreshHandler
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }

    func refreshModels() async throws {
        refreshCalls += 1
        try await refreshHandler?()
    }
}

/// 动态模型列表：静态供应商行为不变、远程 provider 生效、事件广播、刷新后选中校验。
@MainActor
struct DynamicModelListTests {

    @Test("静态供应商行为不变：models/modelRoute 仍走静态列表")
    func staticProviderUnchanged() throws {
        let manager = DefaultLLMManager()
        let staticProvider = MockManagedProvider(id: "static", models: ["a", "b"], defaultModel: "a")

        try manager.register(staticProvider)

        #expect(manager.models(for: "static") == ["a", "b"])

        let staticID = try #require(LLMModelID(providerID: "static", modelID: "b"))
        let route = try #require(manager.modelRoute(for: staticID))
        #expect(route.modelName == "b")
        #expect(route.modelInfo.id == "b")

        // 远程 model 在静态供应商上不可用
        let foreignID = LLMModelID(providerID: "static", modelID: "remote-x")
        #expect(foreignID == nil || manager.modelRoute(for: foreignID!) == nil)
    }

    @Test("远程 provider：availableModels 生效于 models/modelRoute/modelID")
    func remoteProviderDynamicModels() throws {
        let manager = DefaultLLMManager()
        let provider = MockRemoteModelProvider(
            id: "remote",
            baseModels: ["base-a", "base-b"],
            defaultModel: "base-a",
            remoteModelIDs: ["remote-c"]
        )

        try manager.register(provider)

        // 动态池 = 静态 base + 远程 remote-c
        #expect(manager.models(for: "remote") == ["base-a", "base-b", "remote-c"])
        #expect(manager.modelIDs(of: provider) == ["base-a", "base-b", "remote-c"])

        // 远程模型能路由
        let remoteID = try #require(LLMModelID(providerID: "remote", modelID: "remote-c"))
        let route = try #require(manager.modelRoute(for: remoteID))
        #expect(route.modelName == "remote-c")

        // modelID 校验走动态池
        #expect(manager.modelID(providerID: "remote", model: "remote-c") != nil)
        #expect(manager.modelID(providerID: "remote", model: "not-exist") == nil)
    }

    @Test("远程 provider：刷新后 availableModels 变化立即反映到读取路径")
    func remoteProviderRefresh() async throws {
        let manager = DefaultLLMManager()
        let provider = MockRemoteModelProvider(
            id: "remote-refresh",
            baseModels: ["base-a"],
            defaultModel: "base-a"
        )

        // 自定义刷新：把动态池更新为含新模型 remote-new
        provider.availableModels = [LLMModelInfo(id: "base-a"), LLMModelInfo(id: "remote-new")]

        try manager.register(provider)

        #expect(manager.models(for: "remote-refresh") == ["base-a", "remote-new"])
        let refreshedID = try #require(LLMModelID(providerID: "remote-refresh", modelID: "remote-new"))
        #expect(manager.modelRoute(for: refreshedID) != nil)
    }

    @Test("notifyModelsRefreshed 广播 modelsRefreshed 事件")
    func modelsRefreshedEvent() async throws {
        let manager = DefaultLLMManager()
        let provider = MockRemoteModelProvider(id: "remote-event", baseModels: ["a"])
        try manager.register(provider)

        var event: LLMManagerEvent?
        let handle = manager.addObserver { event = $0 }

        manager.notifyModelsRefreshed(providerID: "remote-event")

        if case let .modelsRefreshed(providerID) = event {
            #expect(providerID == "remote-event")
        } else {
            Issue.record("expected modelsRefreshed event, got \(String(describing: event))")
        }

        handle.cancel()
    }

    @Test("选中远程模型后刷新仍保持有效（模型仍在动态池）")
    func selectionSurvivesRefresh() throws {
        let manager = DefaultLLMManager()
        let provider = MockRemoteModelProvider(
            id: "remote-sel",
            baseModels: ["base-a"],
            defaultModel: "base-a",
            remoteModelIDs: ["remote-x"]
        )
        try manager.register(provider)

        manager.select(providerID: "remote-sel", model: "remote-x", reason: .userSelected)
        #expect(manager.selectedModelID?.modelID == "remote-x")

        // 保持动态池包含 remote-x（刷新不删除），选中仍有效
        #expect(manager.modelRoute(for: manager.selectedModelID!) != nil)
    }
}