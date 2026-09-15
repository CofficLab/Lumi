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
    @Published private(set) var selectedPluginID: String?
    @Published private(set) var isDisablingAll = false

    private let capability: any PluginManagementCapability
    private let docsProvider: (any DocsViewProviding)?
    private var updatingPluginIDs = Set<String>()

    init(
        capability: any PluginManagementCapability,
        docsProvider: (any DocsViewProviding)?
    ) {
        self.capability = capability
        self.docsProvider = docsProvider
    }

    var filteredPlugins: [PluginManagementItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            let metadata = plugin.metadata
            let matchesCategory = selectedCategory.map { metadata.category == $0 } ?? true
            let matchesKeyword = keyword.isEmpty
                || metadata.name.localizedCaseInsensitiveContains(keyword)
                || metadata.id.localizedCaseInsensitiveContains(keyword)
                || metadata.description.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesKeyword
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

    func setEnabled(_ enabled: Bool, for pluginID: String) {
        guard !isUpdating(pluginID: pluginID) else { return }
        updatingPluginIDs.insert(pluginID)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { updatingPluginIDs.remove(pluginID) }
            if enabled {
                _ = await capability.enablePlugin(id: pluginID)
            } else {
                _ = await capability.disablePlugin(id: pluginID)
            }
        }
    }

    func disableAllPlugins() {
        guard !isDisablingAll else { return }
        isDisablingAll = true
        let enabledPluginIDs = plugins.filter(\.isEnabled).map(\.id)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isDisablingAll = false }
            for pluginID in enabledPluginIDs {
                _ = await capability.disablePlugin(id: pluginID)
            }
        }
    }

    func aboutEntry(for pluginID: String) -> DocsEntry? {
        docsProvider?.aboutEntries.first(where: { $0.id == pluginID })
    }
}
