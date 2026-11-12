import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 供应商声明的轻量任务模型在模型选择器上的标记行为。
///
/// 背景：供应商通过 `LLMProviderInfo.recommendedUtilityModel` 声明一个
/// 「轻量任务模型」，对话标题、上下文摘要等幕后调用会优先使用它，
/// 而不是消耗对话主模型的额度。模型选择器需要把这个声明可视化，
/// 让用户知道哪些模型会被后台自动使用。
///
/// 关键约束：**只做视觉标记，不改变任何行为**。轻量模型仍然可以被
/// 正常选中作为对话主模型，也不影响筛选与搜索。
@MainActor
struct UtilityModelBadgeTests {

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

    @Test("供应商声明的轻量模型被正确识别")
    func declaredUtilityModelIsRecognized() {
        let provider = UtilityTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        #expect(viewModel.utilityModelID(for: provider.providerID) == "utility-model")
        #expect(viewModel.isUtilityModel(providerID: provider.providerID, model: "utility-model"))
        #expect(!viewModel.isUtilityModel(providerID: provider.providerID, model: "heavy-model"))
    }

    @Test("供应商未声明轻量模型时不做任何标记")
    func providerWithoutUtilityModelHasNoMarker() {
        let provider = UtilityTestProvider(recommendedUtilityModel: nil)
        let viewModel = Self.makeViewModel(provider: provider)

        #expect(viewModel.utilityModelID(for: provider.providerID) == nil)
        #expect(!viewModel.isUtilityModel(providerID: provider.providerID, model: "utility-model"))
        #expect(!viewModel.isUtilityModel(providerID: provider.providerID, model: "heavy-model"))
    }

    @Test("未注册供应商不会误判为轻量模型")
    func unknownProviderHasNoMarker() {
        let provider = UtilityTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        #expect(viewModel.utilityModelID(for: "not-registered") == nil)
        #expect(!viewModel.isUtilityModel(providerID: "not-registered", model: "utility-model"))
    }

    @Test("轻量模型仍可被正常选中，且不被筛选或搜索排除")
    func utilityModelRemainsFullyUsable() {
        let provider = UtilityTestProvider()
        let viewModel = Self.makeViewModel(provider: provider)

        // 可见性不受标记影响
        #expect(viewModel.visibleModels(for: provider.providerID).contains("utility-model"))

        // 搜索仍可命中
        viewModel.modelSearchText = "utility"
        #expect(viewModel.visibleModels(for: provider.providerID).contains("utility-model"))

        // 仍可被选中
        viewModel.modelSearchText = ""
        viewModel.select(providerID: provider.providerID, model: "utility-model")
        #expect(viewModel.isSelected(providerID: provider.providerID, model: "utility-model"))
    }
}

/// 测试替身：声明一个轻量任务模型，模型池中同时包含普通模型。
@MainActor
private final class UtilityTestProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo

    init(recommendedUtilityModel: String? = "utility-model") {
        providerInfo = LLMProviderInfo(
            id: "utility-provider",
            displayName: "Utility",
            defaultModel: "heavy-model",
            models: [
                LLMModelInfo(id: "heavy-model", contextWindowSize: 200_000),
                LLMModelInfo(id: "utility-model", contextWindowSize: 200_000),
            ],
            recommendedUtilityModel: recommendedUtilityModel
        )
    }

    var providerID: String { providerInfo.id }
    var availableModels: [LLMModelInfo] { providerInfo.models }

    func refreshModels() async throws {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
