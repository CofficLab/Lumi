import Combine
import KernelCore
import ProviderDocsView
import ProviderPluginManaging

/// 插件管理列表中的一项展示状态。
struct PluginManagementItem: Identifiable {
    let metadata: PluginMetadata
    let isEnabled: Bool

    var id: String { metadata.id }
}

/// 插件管理设置页唯一的数据来源和交互入口。
@MainActor
final class PluginManagementViewModel: ObservableObject {
    @Published private(set) var plugins: [PluginManagementItem] = []
    @Published var searchText = ""
    @Published var selectedCategory: PluginCategory?
    @Published var statusFilter: PluginManagementFilter = .all
    @Published private(set) var selectedPluginID: String?
    @Published private(set) var isDisablingAll = false

    /// 最近一次启停失败的原因；成功后清空。
    ///
    /// 启停失败时界面据此展示错误横幅，避免开关静默停留在与实际不一致的位置。
    @Published private(set) var errorMessage: String?

    private let capability: any PluginManagementCapability
    private let docsCapability: PluginManagerDocsCapability
    private var updatingPluginIDs = Set<String>()

    init(
        capability: any PluginManagementCapability,
        docsCapability: PluginManagerDocsCapability
    ) {
        self.capability = capability
        self.docsCapability = docsCapability
    }

    var filteredPlugins: [PluginManagementItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            let metadata = plugin.metadata
            let matchesCategory = selectedCategory.map { metadata.category == $0 } ?? true
            let matchesStatus = statusFilter.matches(isEnabled: plugin.isEnabled)
            let matchesKeyword = keyword.isEmpty
                || metadata.name.localizedCaseInsensitiveContains(keyword)
                || metadata.id.localizedCaseInsensitiveContains(keyword)
                || metadata.description.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesStatus && matchesKeyword
        }
    }

    var availableCategories: [PluginCategory] {
        let present = Set(plugins.map { $0.metadata.category })
        return PluginCategory.displayOrder
            .filter { present.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var selectedPlugin: PluginManagementItem? {
        if let selectedPluginID,
           let selected = plugins.first(where: { $0.id == selectedPluginID }) {
            return selected
        }
        return filteredPlugins.first ?? plugins.first
    }

    var enabledCount: Int {
        plugins.reduce(0) { $0 + ($1.isEnabled ? 1 : 0) }
    }

    // MARK: - 搜索框显隐

    /// 搜索框的显示阈值：可配置插件数量达到该值才显示搜索框。
    ///
    /// 插件数量少的时候列表一眼就看得完，搜索框只是噪音。
    static let searchVisibilityThreshold = 10

    /// 是否显示搜索框。
    ///
    /// 只看**插件总数**，不看筛选 / 搜索命中的条数：否则用户一输入关键字、
    /// 命中数掉到阈值以下，搜索框就会自己消失，用户没法清空关键字。
    var showsSearchBar: Bool {
        plugins.count >= Self.searchVisibilityThreshold
    }

    // MARK: - 错误提示

    /// 清除错误提示。
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 数据源

    /// Observer 收到插件列表或启用状态事件后调用，重新生成整个页面状态。
    func refresh() {
        plugins = capability.allPlugins
            .filter { $0.metadata.policy.isConfigurable }
            .map { plugin in
                PluginManagementItem(
                    metadata: plugin.metadata,
                    isEnabled: capability.isEnabled(id: plugin.id)
                )
            }
        normalizeSelection()
    }

    func selectPlugin(id: String) {
        guard plugins.contains(where: { $0.id == id }) else { return }
        selectedPluginID = id
    }

    func normalizeSelection() {
        guard let selectedPluginID,
              filteredPlugins.contains(where: { $0.id == selectedPluginID }) else {
            self.selectedPluginID = filteredPlugins.first?.id ?? plugins.first?.id
            return
        }
    }

    func isUpdating(pluginID: String) -> Bool {
        updatingPluginIDs.contains(pluginID)
    }

    // MARK: - 启停

    /// 切换单个插件的启用状态。
    ///
    /// 失败时记录原因并重读能力层状态，保证开关不会停留在与实际不一致的位置。
    func setEnabled(_ enabled: Bool, for pluginID: String) {
        guard !isUpdating(pluginID: pluginID) else { return }
        updatingPluginIDs.insert(pluginID)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { updatingPluginIDs.remove(pluginID) }
            let succeeded = enabled
                ? await capability.enablePlugin(id: pluginID)
                : await capability.disablePlugin(id: pluginID)
            refresh()
            errorMessage = succeeded ? nil : capability.lastErrorDescription
        }
    }

    /// 停用全部已启用插件。
    ///
    /// 任一插件停用失败时记录最后一次失败原因，其余插件继续处理。
    func disableAllPlugins() {
        guard !isDisablingAll else { return }
        isDisablingAll = true
        let enabledPluginIDs = plugins.filter(\.isEnabled).map(\.id)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isDisablingAll = false }
            var failure: String?
            for pluginID in enabledPluginIDs {
                guard !(await capability.disablePlugin(id: pluginID)) else { continue }
                failure = capability.lastErrorDescription
            }
            refresh()
            errorMessage = failure
        }
    }

    func aboutEntry(for pluginID: String) -> DocsEntry? {
        docsCapability.aboutEntry(for: pluginID)
    }
}
