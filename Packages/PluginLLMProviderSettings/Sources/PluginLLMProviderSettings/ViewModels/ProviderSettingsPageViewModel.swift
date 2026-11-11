import Combine
import Foundation
import KitLLM
import ProviderLLMManager

/// 云端 / 本地供应商设置页面唯一的数据来源与交互入口。
///
/// 供应商列表、搜索、选中态与自定义供应商变化全部收敛到这里；
/// View 不再直接持有 `LLMManaging` 或 `UserDefinedCloudProviderStore`。
@MainActor
final class ProviderSettingsPageViewModel: ObservableObject {
    @Published var selectedProviderID: String?
    @Published var searchText = ""
    @Published private(set) var customProviderRevision = 0
    /// 远程模型刷新计数：自增以驱动头部模型数重算。
    ///
    /// 头部的模型总数取自动态模型池，远程刷新后必须重算，
    /// 否则会停在刷新前的旧值。
    @Published private(set) var modelsRevision = 0

    private let capability: any ProviderSettingsCapability
    private let isLocalFlag: Bool
    private let downloadViewModel: (String) -> ProviderModelDownloadViewModel?
    private var customCancellable: AnyCancellable?
    private var modelsCancellable: AnyCancellable?

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
        // 远程模型刷新后重算头部的模型总数：动态池可能新增或移除模型。
        modelsCancellable = capability.modelsUpdatedPublisher.sink { [weak self] _ in
            self?.modelsRevision &+= 1
        }
    }

    /// 插件卸载时调用，释放外部订阅。
    func cancel() {
        customCancellable?.cancel()
        customCancellable = nil
        modelsCancellable?.cancel()
        modelsCancellable = nil
    }

    // MARK: - Derived

    /// 本页面是否展示本地供应商（否则为云端供应商）。
    var isLocal: Bool {
        isLocalFlag
    }

    var allProviders: [any SuperLLMProvider] {
        capability.allProviders
    }

    /// 当前作用域（云端 / 本地）内的全部供应商，不受搜索词影响。
    private var scopedProviders: [any SuperLLMProvider] {
        allProviders.filter { $0.providerInfo.isLocal == isLocal }
    }

    var filteredProviders: [any SuperLLMProvider] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return scopedProviders }
        return scopedProviders.filter {
            $0.providerInfo.displayName.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.description.localizedCaseInsensitiveContains(keyword)
                || $0.providerInfo.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 当前选中的供应商。
    ///
    /// 搜索只过滤左侧列表，右侧详情仍按选中 ID 展示；头部统计必须使用
    /// 同一口径，否则搜索排除它时模型数量会错误地变成 0（issue #941）。
    var selectedProvider: (any SuperLLMProvider)? {
        guard let selectedProviderID else { return nil }
        return scopedProviders.first { $0.providerInfo.id == selectedProviderID }
    }

    /// 当前选中供应商的模型总数。
    ///
    /// 必须与右侧详情使用**同一个动态模型池**（`capability.availableModels`）：
    /// 远程型供应商的模型列表来自「远程快照 / 缓存 / 基线」的合并池，
    /// 刷新后可能多于静态基线。只读 `providerInfo.models` 会让同一页面
    /// 对同一供应商给出两个不同的总数。
    var selectedModelCount: Int {
        guard let providerID = selectedProvider?.providerInfo.id else { return 0 }
        return capability.availableModels(for: providerID).count
    }

    var providerCountLabel: String {
        let key = isLocal ? "%lld 个本地供应商" : "%lld 个云端供应商"
        return String(format: pluginLocalization.string(key), Int64(filteredProviders.count))
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
    ///
    /// 只看作用域内的真实供应商：搜索词不是删除，不能借此清空或改写选中项。
    func synchronizeSelection() {
        let ids = scopedProviders.map(\.providerInfo.id)
        if let selectedProviderID, !ids.contains(selectedProviderID) {
            self.selectedProviderID = ids.first
        } else if selectedProviderID == nil {
            selectedProviderID = ids.first
        }
    }

    // MARK: - Private

    private var detailViewModels: [String: ProviderDetailViewModel] = [:]
}
