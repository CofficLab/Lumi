import Combine
import Foundation
import KitLLM

/// 云端 / 本地供应商设置页面唯一的数据来源与交互入口。
///
/// 供应商列表、搜索、选中态与自定义供应商变化全部收敛到这里；
/// View 不再直接持有 `LLMManaging` 或 `UserDefinedCloudProviderStore`。
@MainActor
final class ProviderSettingsPageViewModel: ObservableObject {
    @Published var selectedProviderID: String?
    @Published var searchText = ""
    @Published private(set) var customProviderRevision = 0

    private let capability: any ProviderSettingsCapability
    private let isLocalFlag: Bool
    private let downloadViewModel: (String) -> ProviderModelDownloadViewModel?
    private var customCancellable: AnyCancellable?

    init(
        capability: any ProviderSettingsCapability,
        isLocal: Bool,
        downloadViewModel: @escaping (String) -> ProviderModelDownloadViewModel?
    ) {
        self.capability = capability
        self.isLocalFlag = isLocal
        self.downloadViewModel = downloadViewModel
        customCancellable = capability.customProviderConfigurationsPublisher.sink { [weak self] _ in
            self?.customProviderRevision &+= 1
            self?.synchronizeSelection()
        }
    }

    /// 插件卸载时调用，释放外部订阅。
    func cancel() {
        customCancellable?.cancel()
        customCancellable = nil
    }

    // MARK: - Derived

    /// 本页面是否展示本地供应商（否则为云端供应商）。
    var isLocal: Bool {
        isLocalFlag
    }

    var allProviders: [any SuperLLMProvider] {
        capability.allProviders
    }

    var filteredProviders: [any SuperLLMProvider] {
        let scope = allProviders.filter { $0.providerInfo.isLocal == isLocal }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return scope }
        return scope.filter {
            $0.providerInfo.displayName.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.description.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    var selectedProvider: (any SuperLLMProvider)? {
        guard let selectedProviderID else { return nil }
        return filteredProviders.first { $0.providerInfo.id == selectedProviderID }
    }

    var selectedModelCount: Int {
        selectedProvider?.providerInfo.models.count ?? 0
    }

    var providerCountLabel: String {
        isLocal ? "\(filteredProviders.count) 个本地供应商" : "\(filteredProviders.count) 个云端供应商"
    }

    var headerSystemImage: String {
        isLocal ? "cpu" : "cloud"
    }

    func downloadViewModel(for providerID: String) -> ProviderModelDownloadViewModel? {
        downloadViewModel(providerID)
    }

    func detailViewModel(for providerID: String) -> ProviderDetailViewModel {
        if let cached = detailViewModels[providerID] {
            return cached
        }
        let viewModel = ProviderDetailViewModel(
            capability: capability,
            providerID: providerID,
            downloadViewModel: downloadViewModel(providerID)
        )
        detailViewModels[providerID] = viewModel
        return viewModel
    }

    /// 新建自定义供应商的编辑器（配置为 nil）。
    func makeNewCustomProviderEditor() -> CustomCloudProviderEditor? {
        capability.makeCustomProviderEditor(configuration: nil)
    }

    // MARK: - 用户意图

    func selectProvider(id: String) {
        selectedProviderID = id
    }

    /// 供应商列表变化后保证选中项仍然有效（视图生命周期调用）。
    func synchronizeSelection() {
        let ids = filteredProviders.map(\.providerInfo.id)
        if let selectedProviderID, !ids.contains(selectedProviderID) {
            self.selectedProviderID = ids.first
        } else if selectedProviderID == nil {
            selectedProviderID = ids.first
        }
    }

    // MARK: - Private

    private var detailViewModels: [String: ProviderDetailViewModel] = [:]
}
