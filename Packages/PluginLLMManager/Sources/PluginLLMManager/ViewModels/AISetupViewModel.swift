import Combine
import Foundation
import KitLLM
import PluginLLMProviderSettings

/// AI 设置引导页唯一的数据来源与交互入口。
///
/// 供应商列表、选中态、API Key 与自定义供应商变化全部收敛到这里；
/// View 不再直接持有 `LLMManaging` 或自定义供应商 Store。
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
    private let customProviderStore: UserDefinedCloudProviderStore?
    private var storeCancellable: AnyCancellable?

    init(
        capability: any LLMManagerCapability,
        customProviderStore: UserDefinedCloudProviderStore?
    ) {
        self.capability = capability
        self.customProviderStore = customProviderStore
        storeCancellable = customProviderStore?.$configurations.sink { [weak self] _ in
            self?.synchronizeSelection()
        }
        synchronizeSelection()
    }

    /// 云服务类供应商（本地供应商不参与引导选择）。
    var providers: [any SuperLLMProvider] {
        capability.allProviders().filter { $0.providerInfo.providerType == .cloudService }
    }

    var selectedProvider: (any SuperLLMProvider)? {
        providers.first { $0.providerID == selectedProviderID }
    }

    var customProviderEditorAvailable: Bool {
        customProviderStore != nil
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

    /// 打开自定义供应商编辑器（sheet 呈现）。
    func makeCustomProviderEditor() -> CustomCloudProviderEditor? {
        guard let customProviderStore else { return nil }
        return CustomCloudProviderEditor(store: customProviderStore)
    }
}
