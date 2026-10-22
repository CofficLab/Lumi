import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 供应商详情页「刷新模型列表」的行为。
///
/// 刷新链路跨越三层：Capability（调供应商 + 广播事件）→ ViewModel（状态与错误）
/// → View（入口可见性）。任一环静默失效，用户看到的都是同一个症状：
/// **点刷新没反应，或列表没变**。因此这里逐层锁定。
@MainActor
struct ProviderDetailModelRefreshTests {

    // MARK: - Test doubles

    /// 支持远程模型列表的测试供应商。
    private final class MockRemoteProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        /// 动态模型池；刷新时被替换为 `refreshedModels`。
        private var dynamicModels: [LLMModelInfo]
        private let refreshedModels: [LLMModelInfo]
        /// 刷新时的错误；非 nil 时 `refreshModels()` 抛错。
        private let refreshError: Error?
        /// 刷新调用次数。
        private(set) var refreshCallCount = 0

        init(
            id: String,
            displayName: String = "远程供应商",
            models: [LLMModelInfo] = [LLMModelInfo(id: "model-a")],
            refreshedModels: [LLMModelInfo] = [LLMModelInfo(id: "model-a"), LLMModelInfo(id: "model-b")],
            refreshError: Error? = nil
        ) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: models.first?.id ?? "",
                models: models,
                apiKeyStorageKey: "test.\(id)"
            )
            self.dynamicModels = models
            self.refreshedModels = refreshedModels
            self.refreshError = refreshError
        }

        var providerID: String { providerInfo.id }

        var usesRemoteModelList: Bool { true }

        var availableModels: [LLMModelInfo] { dynamicModels }

        func refreshModels() async throws {
            refreshCallCount += 1
            if let refreshError {
                throw refreshError
            }
            dynamicModels = refreshedModels
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }

    /// 不支持远程模型列表的静态供应商。
    private final class MockStaticProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(id: String, displayName: String = "静态供应商") {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: "model-a",
                models: [LLMModelInfo(id: "model-a")],
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }

    private enum MockError: Error, LocalizedError {
        case networkUnavailable

        var errorDescription: String? {
            switch self {
            case .networkUnavailable: return "网络不可用"
            }
        }
    }

    // MARK: - Helpers

    private func makeCapability(
        manager: DefaultLLMProviderManagerProviding
    ) -> ProviderSettingsCapabilityAdapter {
        ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
    }

    private func makeViewModel(
        capability: ProviderSettingsCapabilityAdapter,
        providerID: String
    ) -> ProviderDetailViewModel {
        ProviderDetailViewModel(
            capability: capability,
            providerID: providerID,
            downloadViewModel: nil
        )
    }

    // MARK: - 入口可见性

    @Test("远程模型源供应商显示刷新入口，静态供应商不显示")
    func exposesRefreshEntryOnlyForRemoteProviders() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockRemoteProvider(id: "remote"))
        try manager.register(MockStaticProvider(id: "static"))
        let capability = makeCapability(manager: manager)

        #expect(makeViewModel(capability: capability, providerID: "remote").canRefreshModels)
        #expect(!makeViewModel(capability: capability, providerID: "static").canRefreshModels)
    }

    @Test("未注册的供应商没有刷新入口")
    func noRefreshEntryForUnregisteredProvider() {
        let manager = DefaultLLMProviderManagerProviding()
        let capability = makeCapability(manager: manager)

        #expect(!makeViewModel(capability: capability, providerID: "missing").canRefreshModels)
    }

    // MARK: - 刷新主链路

    @Test("刷新成功后模型列表同步为新的动态模型池")
    func refreshUpdatesModels() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = MockRemoteProvider(id: "remote")
        try manager.register(provider)
        let capability = makeCapability(manager: manager)

        let viewModel = makeViewModel(capability: capability, providerID: "remote")
        #expect(viewModel.models.map(\.id) == ["model-a"])

        await viewModel.refreshModels()

        #expect(provider.refreshCallCount == 1)
        #expect(viewModel.models.map(\.id) == ["model-a", "model-b"])
        #expect(viewModel.modelRefreshError == nil)
        #expect(!viewModel.isRefreshingModels)
    }

    @Test("刷新失败时保留旧模型池并展示错误原因")
    func refreshFailureKeepsOldModels() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = MockRemoteProvider(id: "remote", refreshError: MockError.networkUnavailable)
        try manager.register(provider)
        let capability = makeCapability(manager: manager)

        let viewModel = makeViewModel(capability: capability, providerID: "remote")

        await viewModel.refreshModels()

        #expect(provider.refreshCallCount == 1)
        #expect(viewModel.models.map(\.id) == ["model-a"])
        #expect(viewModel.modelRefreshError == "网络不可用")
        #expect(!viewModel.isRefreshingModels)
    }

    @Test("刷新成功后清空上一次的错误")
    func refreshSuccessClearsPreviousError() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        let failing = MockRemoteProvider(id: "remote", refreshError: MockError.networkUnavailable)
        try manager.register(failing)
        let capability = makeCapability(manager: manager)

        let viewModel = makeViewModel(capability: capability, providerID: "remote")
        await viewModel.refreshModels()
        #expect(viewModel.modelRefreshError != nil)

        // 换成不失败的供应商：清空错误并刷新成功。
        let succeeding = MockRemoteProvider(id: "remote")
        try manager.register(succeeding)
        await viewModel.refreshModels()

        #expect(viewModel.modelRefreshError == nil)
        #expect(viewModel.models.map(\.id) == ["model-a", "model-b"])
    }

    @Test("不支持远程模型列表的供应商不触发刷新")
    func doesNotRefreshStaticProvider() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockStaticProvider(id: "static"))
        let capability = makeCapability(manager: manager)

        let viewModel = makeViewModel(capability: capability, providerID: "static")
        await viewModel.refreshModels()

        #expect(viewModel.models.map(\.id) == ["model-a"])
        #expect(viewModel.modelRefreshError == nil)
    }

    // MARK: - 事件广播

    @Test("刷新成功会广播 modelsRefreshed 事件")
    func refreshBroadcastsModelsRefreshedEvent() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockRemoteProvider(id: "remote"))

        var refreshedProviderIDs: [String] = []
        let handle = manager.addObserver { event in
            if case let .modelsRefreshed(providerID) = event {
                refreshedProviderIDs.append(providerID)
            }
        }
        defer { handle.cancel() }

        let capability = makeCapability(manager: manager)
        let viewModel = makeViewModel(capability: capability, providerID: "remote")
        await viewModel.refreshModels()

        #expect(refreshedProviderIDs == ["remote"])
    }

    @Test("刷新失败不广播 modelsRefreshed 事件")
    func refreshFailureDoesNotBroadcastEvent() async throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockRemoteProvider(id: "remote", refreshError: MockError.networkUnavailable))

        var refreshedProviderIDs: [String] = []
        let handle = manager.addObserver { event in
            if case let .modelsRefreshed(providerID) = event {
                refreshedProviderIDs.append(providerID)
            }
        }
        defer { handle.cancel() }

        let capability = makeCapability(manager: manager)
        let viewModel = makeViewModel(capability: capability, providerID: "remote")
        await viewModel.refreshModels()

        #expect(refreshedProviderIDs.isEmpty)
    }
}
