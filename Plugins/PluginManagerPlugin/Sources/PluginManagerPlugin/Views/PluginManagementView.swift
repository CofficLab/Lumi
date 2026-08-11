import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

/// 插件管理设置页。
///
/// 两栏布局:左侧为插件列表(搜索 + 分类筛选),右侧为选中插件的详情
/// 与启用开关。对齐旧版本 4.19.0 的体验。
///
/// 刷新机制:`kernel.pluginManager` 直接持有,未把 `objectWillChange`
/// 转发到 kernel,故 `@ObservedObject kernel` 无法感知开关切换。本视图
/// 监听 `.lumiEnabledPluginsDidChange` 通知并递增 `enabledRevision` 触发
/// body 重算,使列表启用状态点、详情页开关与顶部统计即时更新。
///
/// 该文件只保留容器/布局/状态逻辑;具体渲染拆分为:
/// - `PluginManagementHeader`:顶部统计
/// - `PluginListRow`:列表单行
/// - `PluginSettingsDetailView`:右侧详情面板
struct PluginManagementView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    @State private var selectedPluginID: String?
    @State private var searchText = ""
    @State private var selectedCategory: LumiPluginCategory?

    /// 启用状态版本号。`pluginManager` 不通过 kernel 转发 `objectWillChange`,
    /// 改由 `.lumiEnabledPluginsDidChange` 通知驱动:每次插件启用/禁用后递增,
    /// 触发本视图 body 重算,使列表与详情读取到最新的 `effectiveEnabled`。
    @State private var enabledRevision = 0

    var body: some View {
        let _ = enabledRevision // 依赖 enabledRevision,确保通知触发的变更驱动 body 重算

        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                PluginManagementHeader(totalCount: plugins.count, enabledCount: enabledCount)

                HStack(spacing: 0) {
                    pluginListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    pluginDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = selectedPlugin?.id
            }
        }
        .onLumiEnabledPluginsDidChange {
            enabledRevision &+= 1
        }
        .onChange(of: filteredPlugins.map(\.id)) { _, ids in
            guard let selectedPluginID,
                  ids.contains(selectedPluginID)
            else {
                self.selectedPluginID = ids.first
                return
            }
        }
    }

    // MARK: - Data Source

    /// 列表数据源:仅显示用户可配置的插件(对齐 4.19.0 的行为)。
    /// `alwaysOn`(不可禁用)与 `disabled`(不可启用)都不可配置,
    /// 展示在管理列表中没有可操作控件,故一并过滤掉,只保留 `optOut` / `optIn`。
    private var plugins: [LumiPlugin] {
        kernel.pluginManager.allPlugins.filter { $0.policy.isConfigurable }
    }

    /// 列表上出现的分类(按 sortOrder 排序),用于筛选标签栏。
    private var availableCategories: [LumiPluginCategory] {
        let present = Set(plugins.map(\.category))
        return LumiPluginCategory.allCases
            .filter { present.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filteredPlugins: [LumiPlugin] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            let matchesCategory = selectedCategory.map { plugin.category == $0 } ?? true
            let matchesKeyword = keyword.isEmpty
                || plugin.name.localizedCaseInsensitiveContains(keyword)
                || plugin.id.localizedCaseInsensitiveContains(keyword)
                || plugin.pluginDescription.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesKeyword
        }
    }

    private var selectedPlugin: LumiPlugin? {
        if let selectedPluginID,
           let plugin = plugins.first(where: { $0.id == selectedPluginID }) {
            return plugin
        }
        return filteredPlugins.first ?? plugins.first
    }

    /// 当前列表中处于有效启用状态的可配置插件数。
    /// 基于 `plugins`(已过滤 alwaysOn),与列表项数口径一致。
    private var enabledCount: Int {
        plugins.reduce(0) { $0 + (kernel.pluginManager.effectiveEnabled(for: $1) ? 1 : 0) }
    }

    // MARK: - List Pane

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(PluginManagerText.string(PluginManagerText.searchPlugins))
                )

                // 分类筛选标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryChip(title: PluginManagerText.string(PluginManagerText.allCategories), isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(availableCategories, id: \.self) { category in
                            categoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPlugins, id: \.id) { plugin in
                        PluginListRow(
                            plugin: plugin,
                            isSelected: selectedPluginID == plugin.id,
                            isEnabled: kernel.pluginManager.effectiveEnabled(for: plugin)
                        ) {
                            selectedPluginID = plugin.id
                        }
                    }

                    if filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: PluginManagerText.string(PluginManagerText.noPluginsFound)
                        )
                        .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? theme.primary.opacity(0.14) : theme.textSecondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedPlugin {
            PluginSettingsDetailView(kernel: kernel, plugin: selectedPlugin)
        } else {
            AppEmptyState(
                icon: "puzzlepiece.extension",
                title: PluginManagerText.string(PluginManagerText.selectPlugin)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
