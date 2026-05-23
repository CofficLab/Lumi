import SwiftUI
import LumiUI

/// 插件管理视图：顶部分类 Tab 切换，下方展示对应分类的插件列表
struct PluginSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 插件设置存储
    private let settingsStore = AppPluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM

    /// 当前选中的分类，nil 表示"全部"
    @State private var selectedCategory: PluginCategory?

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // 分类 Tab 栏
            categoryTabs
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // 插件列表
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pluginListCard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
            }

            // 底部统计
            AppSettingsStatsBar(
                "共 \(filteredPlugins.count) 个插件 · \(enabledCount) 个已启用"
            )
        }
        .onAppear {
            loadPluginStates()
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryTab(title: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { category in
                    categoryTab(
                        title: category.displayName,
                        icon: category.systemImage,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func categoryTab(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.appCaption)
                }
                Text(title)
                    .font(.appCaption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            .background(
                Capsule()
                    .fill(isSelected ? theme.appAccentSoftFill : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? theme.primary.opacity(0.3) : theme.appDivider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plugin List

    private var pluginListCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredPlugins.enumerated()), id: \.element.instanceLabel) { index, plugin in
                    let pluginType = type(of: plugin)
                    let pluginId = plugin.instanceLabel

                    AppSettingsPluginToggleRow(
                        name: pluginType.displayName,
                        description: pluginType.description,
                        icon: pluginType.iconName,
                        isEnabled: Binding(
                            get: { pluginStates[pluginId, default: true] },
                            set: { newValue in
                                pluginStates[pluginId] = newValue
                                settingsStore.setPluginEnabled(pluginId, enabled: newValue)
                            }
                        )
                    )

                    if index < filteredPlugins.count - 1 {
                        AppSettingsDivider()
                    }
                }

                if filteredPlugins.isEmpty {
                    emptyStateContent
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)

            Text("该分类下暂无可配置的插件")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data

    /// 有可配置插件的分类列表（按 sortOrder 排序）
    private var availableCategories: [PluginCategory] {
        groupedPlugins.map(\.category)
    }

    /// 按分类分组的可配置插件
    private var groupedPlugins: [(category: PluginCategory, plugins: [any SuperPlugin])] {
        pluginProvider.getConfigurablePluginsGroupedByCategory()
    }

    /// 当前筛选的插件列表
    private var filteredPlugins: [any SuperPlugin] {
        if let selectedCategory {
            return groupedPlugins
                .first(where: { $0.category == selectedCategory })?
                .plugins ?? []
        }
        // 全部：按分类顺序扁平化
        return groupedPlugins.flatMap(\.plugins)
    }

    /// 已启用的插件数量
    private var enabledCount: Int {
        filteredPlugins.filter { pluginStates[$0.instanceLabel, default: true] }.count
    }

    /// 加载插件状态
    private func loadPluginStates() {
        var states: [String: Bool] = [:]
        for plugin in pluginProvider.plugins.filter({ type(of: $0).isConfigurable }) {
            let pluginType = type(of: plugin)
            states[pluginType.id] = settingsStore.isPluginEnabled(pluginType.id, defaultEnabled: pluginType.enable)
        }
        pluginStates = states
    }
}

// MARK: - Preview

#Preview("Plugin Settings") {
    PluginSettingsView()
        .frame(width: 600, height: 500)
        .inRootView()
}
