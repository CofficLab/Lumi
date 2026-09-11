import Combine
import Foundation
import KitLLM

/// 单个供应商详情唯一的数据来源与交互入口。
///
/// API Key 读写、选中模型、自定义供应商编辑/删除与下载能力全部收敛到这里；
/// View 不再直接持有 `LLMManaging`、`SuperLLMProvider` 或 Store，
/// 也不再对外部 Provider 做 downcast。
@MainActor
final class ProviderDetailViewModel: ObservableObject {
    @Published var apiKey = ""
    @Published private(set) var savedAPIKey = ""
    @Published private(set) var apiKeySaveError: String?
    @Published private(set) var isCustomProvider = false
    @Published private(set) var providerID: String
    @Published private(set) var displayName: String
    @Published private(set) var providerDescription: String
    @Published private(set) var websiteURL: URL?
    @Published private(set) var isLocal: Bool
    @Published private(set) var models: [LLMModelInfo] = []
    @Published private(set) var selectedProviderID: String?
    @Published private(set) var selectedModel: String?
    @Published private(set) var downloadCapability: (any ModelDownloadCapability)?
    @Published private(set) var downloadViewModel: ProviderModelDownloadViewModel?

    private let capability: any ProviderSettingsCapability
    private var customCancellable: AnyCancellable?

    init(
        capability: any ProviderSettingsCapability,
        providerID: String,
        downloadViewModel: ProviderModelDownloadViewModel?
    ) {
        self.capability = capability
        self.providerID = providerID
        self.downloadViewModel = downloadViewModel
        let info = capability.provider(id: providerID)?.providerInfo
        displayName = info?.displayName ?? providerID
        providerDescription = info?.description ?? ""
        websiteURL = info?.websiteURL
        isLocal = info?.isLocal ?? false
        models = info?.models ?? []
        selectedProviderID = capability.selectedProviderID
        selectedModel = capability.selectedModel
        downloadCapability = capability.makeModelDownloadCapability(for: providerID)
        isCustomProvider = capability.isCustomProvider(id: providerID)
        loadAPIKey()
        customCancellable = capability.customProviderConfigurationsPublisher.sink { [weak self] _ in
            self?.isCustomProvider = self?.capability.isCustomProvider(id: providerID) ?? false
        }
    }

    // MARK: - Derived

    var canEditCustomProvider: Bool {
        isCustomProvider
    }

    // MARK: - 用户意图

    func select(modelID: String) {
        capability.select(providerID: providerID, model: modelID)
        selectedProviderID = capability.selectedProviderID
        selectedModel = capability.selectedModel
    }

    func isModelSelected(_ modelID: String) -> Bool {
        selectedProviderID == providerID && selectedModel == modelID
    }

    func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        capability.setAPIKey(trimmed, for: providerID)
        savedAPIKey = trimmed
        apiKey = trimmed
        apiKeySaveError = nil
    }

    func removeAPIKey() {
        capability.removeAPIKey(for: providerID)
        savedAPIKey = ""
        apiKey = ""
        apiKeySaveError = nil
    }

    func removeCustomProvider() {
        capability.removeCustomProvider(id: providerID)
    }

    func makeCustomProviderEditor() -> CustomCloudProviderEditor? {
        capability.makeCustomProviderEditor(
            configuration: capability.customProviderConfiguration(id: providerID)
        )
    }

    // MARK: - Private

    private func loadAPIKey() {
        savedAPIKey = capability.apiKey(for: providerID)
        apiKey = savedAPIKey
        apiKeySaveError = nil
    }
}
