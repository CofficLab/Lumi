import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 远程模型刷新后，渲染层必须立即看到新模型，无需重开 popover。
///
/// 复现场景：供应商静态清单 6 个，远程返回 9 个（id 与静态清单不重叠），
/// 合并后应为 15 个。点击刷新成功后 UI 不重开也要显示 15 个。
@MainActor
struct ModelListViewRenderTests {

    /// 远程返回的模型 id（刻意与静态清单 `static-a…f` 不重叠，便于断言）。
    private static let remoteCatalog = [
        "MiniMax-M3.1-Flash-Preview", "MiniMax-M3", "MiniMax-M2.7",
        "MiniMax-M2.7-highspeed", "MiniMax-M2.5", "MiniMax-M2.5-highspeed",
        "MiniMax-M2.1", "MiniMax-M2.1-highspeed", "MiniMax-M2",
    ]

    private static let staticCount = 6
    private static let remoteCount = 9
    private static var mergedCount: Int { staticCount + remoteCount }

    @Test("刷新后 box 快照与渲染管线同步更新，无需重开 popover")
    func visibleModelsFollowSnapshot() async throws {
        let provider = RenderTestProvider()
        let manager = DefaultLLMManager()
        try manager.register(provider)

        let box = LLMProviderManagerBox(manager: manager)
        let viewModel = ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toast: nil
        )
        viewModel.selectedProviderID = provider.providerID

        // 刷新前：只有静态清单
        #expect(viewModel.models(for: provider.providerID).count == Self.staticCount)

        provider.injectRemoteModels(Self.remoteCatalog)
        await viewModel.refreshModels(providerID: provider.providerID)

        #expect(provider.availableModels.count == Self.mergedCount, "provider 应合并为 \(Self.mergedCount) 个")
        #expect(box.models(for: provider.providerID).count == Self.mergedCount, "box 快照应同步")

        // 关键断言：不重开 popover，UI 也必须看到全部模型
        let visible = viewModel.visibleModels(for: provider.providerID)
        #expect(viewModel.models(for: provider.providerID).count == Self.mergedCount)
        #expect(visible.count == Self.mergedCount)
        #expect(visible.contains("MiniMax-M2.1"))
    }

    @Test("远程新增模型带元数据进入 UI，不被分类筛选误过滤")
    func remoteModelsCarryMetadata() async throws {
        let provider = RenderTestProvider()
        let manager = DefaultLLMManager()
        try manager.register(provider)
        let box = LLMProviderManagerBox(manager: manager)
        let viewModel = ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toast: nil
        )
        viewModel.selectedProviderID = provider.providerID

        provider.injectRemoteModels(Self.remoteCatalog)
        await viewModel.refreshModels(providerID: provider.providerID)

        // 每个模型都要有元数据条目，否则 displayName 会退化成裸 id
        let infos = viewModel.modelInfoMap(for: provider.providerID)
        #expect(infos.count == Self.mergedCount)
        #expect(infos["MiniMax-M2.1"] != nil)
        #expect(
            ModelCategory.all.includes(model: "MiniMax-M2.1", modelInfo: infos["MiniMax-M2.1"])
        )
    }

    @Test("静态清单兜底：远程为空时仍为 6")
    func fallsBackToStaticCatalog() throws {
        let provider = RenderTestProvider()
        let manager = DefaultLLMManager()
        try manager.register(provider)
        let box = LLMProviderManagerBox(manager: manager)
        let viewModel = ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toast: nil
        )
        viewModel.selectedProviderID = provider.providerID

        #expect(viewModel.visibleModels(for: provider.providerID).count == Self.staticCount)
    }
}

/// 渲染测试替身：静态 6 个，远程可注入，复刻 `VendorLLMProvider` 的合并策略。
@MainActor
private final class RenderTestProvider: ManagedLLMProvider {
    let providerInfo = LLMProviderInfo(
        id: "render-provider",
        displayName: "Render",
        defaultModel: "static-a",
        models: [
            LLMModelInfo(id: "static-a"), LLMModelInfo(id: "static-b"),
            LLMModelInfo(id: "static-c"), LLMModelInfo(id: "static-d"),
            LLMModelInfo(id: "static-e"), LLMModelInfo(id: "static-f"),
        ]
    )
    private var remote: [LLMModelInfo] = []

    var providerID: String { providerInfo.id }
    var usesRemoteModelList: Bool { true }

    /// 模拟远程拉取成功返回的模型列表。
    func injectRemoteModels(_ ids: [String]) {
        remote = ids.map { LLMModelInfo(id: $0) }
    }

    var availableModels: [LLMModelInfo] {
        guard !remote.isEmpty else { return providerInfo.models }
        var seen = Set(providerInfo.models.map(\.id))
        var merged = providerInfo.models
        for model in remote where !seen.contains(model.id) {
            merged.append(model)
            seen.insert(model.id)
        }
        return merged
    }

    func refreshModels() async throws {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}