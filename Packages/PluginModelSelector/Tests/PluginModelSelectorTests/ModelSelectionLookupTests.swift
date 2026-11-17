import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 模型行选中态的推导路径（#1255 回归）。
///
/// 列表每行渲染都会询问一次选中态。历史实现经 `box.modelID` 回查管理器，
/// 管理器再扫描整个动态模型池——远程供应商每次读取 `availableModels`
/// 还会重建合并列表，行数 × 池大小接近平方级的主线程开销。选中态必须
/// 直接从 VM 已加载的快照推导，不得触达供应商模型池。
@MainActor
struct ModelSelectionLookupTests {

    private static func makeViewModel(provider: CountingPoolProvider) -> ModelSelectorViewModel {
        let manager = DefaultLLMManager()
        try? manager.register(provider)
        let box = LLMProviderManagerBox(manager: manager)
        return ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toastCapability: ModelSelectorToastCapabilityAdapter(toast: nil)
        )
    }

    @Test("选中态命中且仅命中当前生效模型")
    func selectionMatchesOnlyTheActiveModel() {
        let provider = CountingPoolProvider()
        let viewModel = Self.makeViewModel(provider: provider)
        // 全局选中态可能被同进程其他用例持久化过，先建立已知基线。
        viewModel.select(providerID: provider.providerID, model: "alpha-model")

        #expect(viewModel.isSelected(providerID: provider.providerID, model: "alpha-model"))
        #expect(!viewModel.isSelected(providerID: provider.providerID, model: "beta-model"))
        #expect(!viewModel.isSelected(providerID: "other-provider", model: "alpha-model"))
    }

    @Test("选中态推导不得回查供应商模型池")
    func selectionCheckDoesNotRescanProviderPool() {
        let provider = CountingPoolProvider()
        let viewModel = Self.makeViewModel(provider: provider)
        viewModel.select(providerID: provider.providerID, model: "beta-model")

        // 建立快照与选中态的过程允许读池；此后渲染阶段不得再读。
        provider.resetReadCount()
        for model in viewModel.models(for: provider.providerID) {
            _ = viewModel.isSelected(providerID: provider.providerID, model: model)
        }

        #expect(provider.availableModelsReadCount == 0, "选中态必须从快照推导，不得重扫模型池")
    }

    @Test("切换选中后高亮随之移动")
    func highlightFollowsSelectionChange() {
        let provider = CountingPoolProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        viewModel.select(providerID: provider.providerID, model: "alpha-model")
        #expect(viewModel.isSelected(providerID: provider.providerID, model: "alpha-model"))

        viewModel.select(providerID: provider.providerID, model: "beta-model")
        #expect(!viewModel.isSelected(providerID: provider.providerID, model: "alpha-model"))
        #expect(viewModel.isSelected(providerID: provider.providerID, model: "beta-model"))
    }
}

/// 测试替身：统计 `availableModels` 被读取的次数，用于断言选中态推导
/// 不再触发模型池重扫（#1255）。
@MainActor
private final class CountingPoolProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo
    private(set) var availableModelsReadCount = 0

    init() {
        providerInfo = LLMProviderInfo(
            id: "lookup-provider",
            displayName: "Lookup",
            defaultModel: "alpha-model",
            models: [
                LLMModelInfo(id: "alpha-model", contextWindowSize: 128_000),
                LLMModelInfo(id: "beta-model", contextWindowSize: 128_000),
            ]
        )
    }

    var providerID: String { providerInfo.id }

    var availableModels: [LLMModelInfo] {
        availableModelsReadCount += 1
        return providerInfo.models
    }

    func resetReadCount() {
        availableModelsReadCount = 0
    }

    func refreshModels() async throws {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
