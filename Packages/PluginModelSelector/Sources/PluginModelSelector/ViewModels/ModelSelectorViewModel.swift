import Combine
import Foundation
import KitLLM
import ProviderLLMManager

/// 模型选择器唯一的数据来源与交互入口。
///
/// 供应商/模型目录快照、选中态、用量、搜索与分类状态全部收敛到这里；
/// Provider/用量变化由本 VM 内部订阅（等价于插件层 Observer 的职责），
/// View 不再持有 `LLMProviderManagerBox` 的 ObserverHandle 或外部 ObservableObject。
@MainActor
final class ModelSelectorViewModel: ObservableObject {
    @Published private(set) var revision = 0
    /// 浏览游标：用户当前点开的供应商，只决定右栏展示哪些模型，不写回内核。
    ///
    /// 与 `activeProviderID` 必须分开：前者是导航态，后者是真正生效的选择。
    @Published var selectedProviderID: String?
    /// 实际生效的供应商（已提交到会话/全局设置）。
    ///
    /// 供应商列表右侧的对号由它决定，与浏览高亮互不干扰。
    @Published private(set) var activeProviderID: String?
    @Published private(set) var selectedModel: String?
    @Published private(set) var selectedModelID: String?
    @Published private(set) var providerInfos: [LLMProviderInfo] = []
    @Published private(set) var modelIDs: [String: [String]] = [:]
    /// providerID -> 模型元数据（动态模型池）。
    ///
    /// 与 `modelIDs` 同源。远程刷新新增的模型只存在于动态池，
    /// 读取 `providerInfo.models` 会漏掉它们。
    @Published private(set) var modelInfos: [String: [LLMModelInfo]] = [:]
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
    private let toastCapability: ModelSelectorToastCapability
    private var boxObserverHandle: (any LLMProviderManagerBox.ObserverHandle)?
    private var usageCancellable: AnyCancellable?

    init(
        box: LLMProviderManagerBox,
        usageStore: ProviderUsageStore,
        toastCapability: ModelSelectorToastCapability
    ) {
        self.box = box
        self.usageStore = usageStore
        self.toastCapability = toastCapability

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

    /// 指定供应商的模型元数据（动态模型池）。
    ///
    /// 远程刷新新增的模型不在 `providerInfo.models` 中，必须查这里。
    func modelInfoMap(for providerID: String) -> [String: LLMModelInfo] {
        guard let models = modelInfos[providerID] else { return [:] }
        return Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
    }

    /// 类别筛选 + 搜索框文本过滤后的可见模型列表。
    ///
    /// 从 View 下沉到此处：渲染逻辑只依赖 ViewModel 快照，可被单元测试直接覆盖，
    /// 也避免 View 里重复实现同一套过滤规则。
    func visibleModels(for providerID: String) -> [String] {
        let models = models(for: providerID)
        let infos = modelInfoMap(for: providerID)
        let query = activeModelSearchText

        return models
            .filter { model in
                selectedCategory.includes(model: model, modelInfo: infos[model])
            }
            .sorted { lhs, rhs in
                let lhsName = infos[lhs]?.displayName ?? lhs
                let rhsName = infos[rhs]?.displayName ?? rhs
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
            .filter { model in
                query.isEmpty
                    || model.localizedCaseInsensitiveContains(query)
                    || (infos[model]?.displayName ?? model).localizedCaseInsensitiveContains(query)
            }
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

    // MARK: - Remote model refresh

    /// 指定供应商是否支持远程模型列表刷新。
    func canRefreshModels(providerID: String) -> Bool {
        box.manager.provider(id: providerID)?.usesRemoteModelList ?? false
    }

    /// 刷新指定供应商的远程模型列表。
    ///
    /// 成功时通过 `notifyModelsRefreshed` 通知管理器广播事件，
    /// box 观察者会自动刷新快照，UI 随之更新。
    func refreshModels(providerID: String) async {
        guard let provider = box.manager.provider(id: providerID) else { return }
        do {
            try await provider.refreshModels()
            box.manager.notifyModelsRefreshed(providerID: providerID)
            toastCapability.notify(
                pluginLocalization.string("Models refreshed"),
                detail: provider.providerInfo.displayName,
                style: .success
            )
        } catch {
            toastCapability.notify(
                pluginLocalization.string("Refresh failed"),
                detail: error.localizedDescription,
                style: .error
            )
        }
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
        toastCapability.notify(
            pluginLocalization.string("Switched to"),
            detail: "\(providerDisplayName) · \(modelDisplayName)",
            style: .success
        )
    }

    // MARK: - Private

    private func modelInfo(for providerID: String, model: String) -> LLMModelInfo? {
        modelInfos[providerID]?.first { $0.id == model }
    }

    private func refreshSnapshots() {
        // 浏览中的选中态不随外部事件回跳，仅刷新目录快照。
        selectedModel = box.selectedModel
        selectedModelID = box.selectedModelID
        // 生效中的供应商由已提交的 modelID 反推，不复用浏览游标，
        // 否则用户点开别的供应商时对号会跟着高亮跑，失去指示作用。
        activeProviderID = selectedModelID.flatMap { LLMModelID(rawValue: $0)?.providerID }
        providerInfos = box.providerInfos
        modelIDs = box.modelIDs
        modelInfos = box.modelInfos
        usageRecords = usageStore.records
        revision &+= 1
    }
}
