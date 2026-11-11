import Combine
import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 远程供应商的模型总数必须与详情使用**同一个动态模型池**。
///
/// ## 为什么要有这条测试
///
/// 设置页右侧详情读 `capability.availableModels(for:)`（远程型返回
/// 「远程快照 / 缓存 / 基线」的合并池），而头部「多少个模型」曾固定读
/// `providerInfo.models.count`（静态基线）。远程目录新增模型后，刷新会让
/// 详情多出一项，头部数字却停在旧值——同一页面对同一供应商给出两个总数。
///
/// 修复后：头部读动态池，并在远程刷新事件后同步更新。
@MainActor
struct ProviderSettingsRemoteModelCountTests {

    // MARK: - Test doubles

    /// 可远程增删模型的供应商替身。
    private final class DynamicRemoteProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        /// 当前远程快照中的模型；刷新可整体替换。
        var remoteModels: [LLMModelInfo]

        init(
            id: String,
            displayName: String,
            baseModels: [String],
            remoteModels: [String]
        ) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: baseModels.first ?? "",
                models: baseModels.map { LLMModelInfo(id: $0) },
                apiKeyStorageKey: "test.\(id)"
            )
            self.remoteModels = remoteModels.map { LLMModelInfo(id: $0) }
        }

        var providerID: String { providerInfo.id }

        var usesRemoteModelList: Bool { true }

        var availableModels: [LLMModelInfo] {
            var seen = Set(providerInfo.models.map(\.id))
            var merged = providerInfo.models
            for model in remoteModels where !seen.contains(model.id) {
                merged.append(model)
                seen.insert(model.id)
            }
            return merged
        }

        func refreshModels() async throws {}

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }

    // MARK: - Helpers

    private func makeViewModel(
        capability: ProviderSettingsCapabilityAdapter
    ) -> ProviderSettingsPageViewModel {
        ProviderSettingsPageViewModel(
            capability: capability,
            isLocal: false,
            downloadViewModel: { _ in nil }
        )
    }

    // MARK: - Tests

    @Test("头部模型数取自动态模型池而不是静态基线")
    func headerCountUsesDynamicPool() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = DynamicRemoteProvider(
            id: "goatplan",
            displayName: "GoatPlan",
            baseModels: ["base-a", "base-b"],
            remoteModels: ["remote-r"]
        )
        try manager.register(provider)
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
        let viewModel = makeViewModel(capability: capability)

        viewModel.selectProvider(id: "goatplan")

        #expect(
            provider.providerInfo.models.count == 2,
            "静态基线用于对照"
        )
        #expect(
            viewModel.selectedModelCount == 3,
            "头部应统计动态模型池（2 个基线 + 1 个远程），实际 \(viewModel.selectedModelCount)"
        )
    }

    @Test("远程刷新新增模型后头部模型数同步更新")
    func headerCountFollowsRemoteRefresh() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = DynamicRemoteProvider(
            id: "goatplan-refresh",
            displayName: "GoatPlan",
            baseModels: ["base-a"],
            remoteModels: []
        )
        try manager.register(provider)
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
        let viewModel = makeViewModel(capability: capability)

        viewModel.selectProvider(id: "goatplan-refresh")
        #expect(viewModel.selectedModelCount == 1)
        let revisionBefore = viewModel.modelsRevision

        // 远程快照新增一个模型，随后广播刷新事件。
        provider.remoteModels = [LLMModelInfo(id: "remote-new")]
        manager.notifyModelsRefreshed(providerID: "goatplan-refresh")

        #expect(
            viewModel.selectedModelCount == 2,
            "刷新后头部模型数未更新，实际 \(viewModel.selectedModelCount)"
        )
        #expect(
            viewModel.modelsRevision > revisionBefore,
            "刷新后必须发出变更信号，界面才会重算头部数字"
        )
    }

    @Test("头部模型数与详情模型数始终一致")
    func headerCountMatchesDetailCount() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = DynamicRemoteProvider(
            id: "goatplan-parity",
            displayName: "GoatPlan",
            baseModels: ["base-a"],
            remoteModels: ["remote-r", "remote-s"]
        )
        try manager.register(provider)
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
        let viewModel = makeViewModel(capability: capability)

        viewModel.selectProvider(id: "goatplan-parity")
        let detail = viewModel.detailViewModel(for: "goatplan-parity")

        #expect(viewModel.selectedModelCount == detail.models.count)

        provider.remoteModels = [LLMModelInfo(id: "remote-r")]
        manager.notifyModelsRefreshed(providerID: "goatplan-parity")

        #expect(
            viewModel.selectedModelCount == detail.models.count,
            "刷新后头部与详情的模型数应仍然一致"
        )
    }

    @Test("静态供应商的模型数不受影响")
    func staticProviderCountUnchanged() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = MockStaticProvider(id: "static", models: ["a", "b", "c"])
        try manager.register(provider)
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
        let viewModel = makeViewModel(capability: capability)

        viewModel.selectProvider(id: "static")

        #expect(viewModel.selectedModelCount == 3)
    }

    /// 静态模型列表的供应商替身。
    private final class MockStaticProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(id: String, models: [String]) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: id,
                defaultModel: models.first ?? "",
                models: models.map { LLMModelInfo(id: $0) },
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }
}
