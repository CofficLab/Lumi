import Combine
import Foundation
import KitLLM
import ProviderLLMManager
import ProviderToast

/// 模型选择器唯一的数据来源与交互入口。
///
/// 供应商/模型目录快照、选中态、用量、搜索与分类状态全部收敛到这里；
/// Provider/用量变化由本 VM 内部订阅（等价于插件层 Observer 的职责），
/// View 不再持有 `LLMProviderManagerBox` 的 ObserverHandle 或外部 ObservableObject。
@MainActor
final class ModelSelectorViewModel: ObservableObject {
    @Published private(set) var revision = 0
    @Published var selectedProviderID: String?
    @Published private(set) var selectedModel: String?
    @Published private(set) var selectedModelID: String?
    @Published private(set) var providerInfos: [LLMProviderInfo] = []
    @Published private(set) var modelIDs: [String: [String]] = [:]
    @Published private(set) var usageRecords: [String: ProviderUsageRecord] = [:]
    @Published var searchText = ""
    @Published var selectedScope = ProviderScope.cloud
    @Published var selectedCategory = ModelCategory.all

    /// 展示模型搜索框的模型数量下限。
    ///
    /// 模型不超过该数量时，列表一屏即可看全，搜索框只占空间不创造价值。
    static let modelSearchThreshold = 8

    private let box: LLMProviderManagerBox
    private let usageStore: ProviderUsageStore
    private let toast: (any ToastProviding)?
    private var boxObserverHandle: (any LLMProviderManagerBox.ObserverHandle)?
    private var usageCancellable: AnyCancellable?

    init(
        box: LLMProviderManagerBox,
        usageStore: ProviderUsageStore,
        toast: (any ToastProviding)?
    ) {
        self.box = box
        self.usageStore = usageStore
        self.toast = toast

        selectedProviderID = box.selectedProviderID ?? box.providerInfos.first?.id
        selectedModel = box.selectedModel
        refreshSnapshots()

        boxObserverHandle = box.addObserver { [weak self] _ in
            self?.refreshSnapshots()
        }
        usageCancellable = usageStore.$records.sink { [weak self] records in
            self?.usageRecords = records
        }
    }

    /// 插件卸载时调用，释放外部观察订阅。
    func cancel() {
        boxObserverHandle?.cancel()
        boxObserverHandle = nil
        usageCancellable?.cancel()
        usageCancellable = nil
    }

    // MARK: - Derived

    var buttonLabel: String {
        guard let selectedModelID,
              let route = box.modelRoute(for: selectedModelID) else {
            return "Select Provider"
        }
        return "\(route.providerInfo.displayName) · \(route.modelInfo.displayName)"
    }

    func providerInfo(id: String) -> LLMProviderInfo? {
        providerInfos.first { $0.id == id }
    }

    func models(for providerID: String) -> [String] {
        modelIDs[providerID] ?? []
    }

    /// 给定模型数量是否值得展示搜索框。
    func shouldShowSearchBar(modelCount: Int) -> Bool {
        modelCount > Self.modelSearchThreshold
    }

    /// 当前选中供应商的模型是否多到值得展示搜索框。
    var showsModelSearchBar: Bool {
        guard let selectedProviderID else { return false }
        return shouldShowSearchBar(modelCount: models(for: selectedProviderID).count)
    }

    /// 实际参与过滤的搜索文本；搜索框不可见时一律视为未搜索，
    /// 避免残留文本把模型从列表里悄悄筛掉。
    var activeModelSearchText: String {
        showsModelSearchBar ? searchText : ""
    }

    func modelID(providerID: String, model: String) -> String? {
        box.modelID(providerID: providerID, model: model)
    }

    func isSelected(providerID: String, model: String) -> Bool {
        modelID(providerID: providerID, model: model) == selectedModelID
    }

    func usageCount(for providerID: String) -> Int {
        usageRecords[providerID]?.count ?? 0
    }

    func isMoreFrequentlyUsed(_ lhs: String, than rhs: String) -> Bool {
        usageStore.isMoreFrequentlyUsed(lhs, than: rhs)
    }

    /// 供应商是否命中当前筛选范围。
    func matchesActiveFilters(_ provider: LLMProviderInfo) -> Bool {
        selectedScope.includes(provider, usageCount: usageCount(for: provider.id))
    }

    // MARK: - Scope 联动（View 生命周期调用）

    /// 初始 scope：存在任意历史用量时默认「常用」，否则按选中供应商对齐。
    func prepareInitialScope() {
        let hasAvailableUsage = providerInfos.contains {
            usageCount(for: $0.id) > 0
        }
        if hasAvailableUsage {
            selectedScope = .frequent
        } else {
            synchronizeScopeWithSelection()
        }
    }

    /// 选中供应商变化时，把筛选范围对齐到本地/云端（「常用」除外）。
    func synchronizeScopeWithSelection() {
        guard selectedScope != .frequent else { return }
        guard
            let selectedProviderID,
            let selectedProvider = providerInfos.first(where: { $0.id == selectedProviderID })
        else { return }

        let scope: ProviderScope = selectedProvider.isLocal ? .local : .cloud
        if selectedScope != scope {
            selectedScope = scope
        }
    }

    /// 筛选范围变化时，若当前选中供应商不在范围内则选中范围内的第一个。
    func selectProviderInCurrentScopeIfNeeded() {
        let scopedProviders = providerInfos.filter(matchesActiveFilters)
        if scopedProviders.contains(where: { $0.id == selectedProviderID }) {
            return
        }
        let next = scopedProviders.first?.id
        if selectedProviderID != next {
            selectedProviderID = next
        }
    }

    // MARK: - 用户意图

    /// 在当前上下文中选择供应商与模型（写入由 capability 路由）。
    func select(providerID: String, model: String?) {
        guard let model,
              let modelID = box.modelID(providerID: providerID, model: model) else { return }
        box.select(modelID: modelID)
        usageStore.recordUse(providerID: providerID)

        let providerDisplayName = providerInfo(id: providerID)?.displayName ?? providerID
        let modelInfo = modelInfo(for: providerID, model: model)
        let modelDisplayName = modelInfo?.displayName ?? model
        toast?.show(
            LumiPluginLocalization.string("Switched to", bundle: .module),
            detail: "\(providerDisplayName) · \(modelDisplayName)",
            style: .success
        )
    }

    // MARK: - Private

    private func modelInfo(for providerID: String, model: String) -> LLMModelInfo? {
        providerInfo(id: providerID)?.models.first { $0.id == model }
    }

    private func refreshSnapshots() {
        // 浏览中的选中态不随外部事件回跳，仅刷新目录快照。
        selectedModel = box.selectedModel
        selectedModelID = box.selectedModelID
        providerInfos = box.providerInfos
        modelIDs = box.modelIDs
        usageRecords = usageStore.records
        revision &+= 1
    }
}
