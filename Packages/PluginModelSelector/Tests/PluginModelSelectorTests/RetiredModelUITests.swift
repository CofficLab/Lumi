import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 退役模型（上游已不再提供）在 UI 上的行为。
///
/// 关键约束：**只做视觉区分，不隐藏、不剔除**。用户仍可能需要选中它
/// （配置里已选、离线兜底等），隐藏会让「选中的模型凭空消失」。
@MainActor
struct RetiredModelUITests {

    private static func makeViewModel(
        provider: ManagedLLMProvider
    ) -> ModelSelectorViewModel {
        let manager = DefaultLLMManager()
        try? manager.register(provider)
        let box = LLMProviderManagerBox(manager: manager)
        let viewModel = ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toastCapability: ModelSelectorToastCapabilityAdapter(toast: nil)
        )
        viewModel.selectedProviderID = provider.providerID
        return viewModel
    }

    @Test("退役模型仍出现在可见列表中，不被隐藏")
    func retiredModelRemainsVisible() {
        let provider = RetiredTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        let visible = viewModel.visibleModels(for: provider.providerID)
        #expect(visible.contains("retired-model"), "退役模型不应被隐藏")
        #expect(visible.contains("live-model"))
    }

    @Test("退役模型的元数据带 isRetired 标记，供 View 区分样式")
    func retiredModelCarriesFlag() throws {
        let provider = RetiredTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        let infos = viewModel.modelInfoMap(for: provider.providerID)
        let retired = try #require(infos["retired-model"])
        let live = try #require(infos["live-model"])

        #expect(retired.isRetired == true)
        #expect(live.isRetired == false)
    }

    @Test("退役模型可被搜索命中（不做任何过滤排除）")
    func retiredModelIsSearchable() {
        let provider = RetiredTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)
        viewModel.searchText = "retired"

        let visible = viewModel.visibleModels(for: provider.providerID)
        #expect(visible.contains("retired-model"), "退役模型不应被搜索过滤掉")
    }

    @Test("退役模型在能力分类筛选下仍按自身能力归类，不被特殊对待")
    func retiredModelFollowsCategoryRules() throws {
        let provider = RetiredTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)
        viewModel.selectedCategory = .tools

        let infos = viewModel.modelInfoMap(for: provider.providerID)
        let retired = try #require(infos["retired-model"])
        // 退役与否与能力分类无关：该模型支持工具调用，应在 tools 类中可见
        #expect(retired.supportsTools == true)
        #expect(viewModel.visibleModels(for: provider.providerID).contains("retired-model"))
    }
}

/// 渲染测试替身：静态清单含一个已退役模型。
@MainActor
private final class RetiredTestProvider: ManagedLLMProvider {
    let providerInfo = LLMProviderInfo(
        id: "retired-provider",
        displayName: "Retired",
        defaultModel: "live-model",
        models: [
            LLMModelInfo(id: "live-model", contextWindowSize: 200_000),
            // 上游已下线，但清单保留并标记，供 UI 灰显
            LLMModelInfo(id: "retired-model", contextWindowSize: 100_000, isRetired: true),
        ]
    )

    var providerID: String { providerInfo.id }
    var availableModels: [LLMModelInfo] { providerInfo.models }

    func refreshModels() async throws {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}