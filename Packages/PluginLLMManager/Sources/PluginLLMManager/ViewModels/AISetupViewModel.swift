import Combine
import Foundation
import KitLLM

/// AI 设置引导页唯一的数据来源与交互入口。
///
/// 供应商列表、选中态与 API Key 变化全部收敛到这里；View 不再直接持有
/// `LLMManaging`。自定义供应商的配置入口只在设置里提供，不在此引导页重复。
@MainActor
final class AISetupViewModel: ObservableObject {
    @Published var selectedProviderID = "" {
        didSet {
            guard selectedProviderID != oldValue else { return }
            apiKey = selectedProvider?.getApiKey() ?? ""
            didSave = selectedProvider?.hasApiKey() ?? false
        }
    }
    @Published var apiKey = ""
    @Published private(set) var didSave = false

    private let capability: any LLMManagerCapability

    init(capability: any LLMManagerCapability) {
        self.capability = capability
        synchronizeSelection()
    }

    /// 云服务类供应商（本地供应商不参与引导选择）。
    var providers: [any SuperLLMProvider] {
        capability.allProviders().filter { $0.providerInfo.providerType == .cloudService }
    }

    var selectedProvider: (any SuperLLMProvider)? {
        providers.first { $0.providerID == selectedProviderID }
    }

    // MARK: - 用户意图

    func saveAPIKey() {
        guard let provider = selectedProvider else { return }
        provider.setApiKey(apiKey)
        capability.select(providerID: provider.providerID, model: nil)
        apiKey = provider.getApiKey()
        didSave = true
    }

    func synchronizeSelection() {
        guard selectedProviderID.isEmpty else { return }
        let managerSelection = capability.selectedProviderID
        selectedProviderID = providers.first(where: { $0.providerID == managerSelection })?.providerID
            ?? providers.first?.providerID
            ?? ""
        apiKey = selectedProvider?.getApiKey() ?? ""
        didSave = selectedProvider?.hasApiKey() ?? false
    }
}
