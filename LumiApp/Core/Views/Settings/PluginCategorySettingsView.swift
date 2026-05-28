import SwiftUI
import LumiUI
import AgentToolKit

/// 插件分类设置视图：展示指定分类下所有可配置插件的开关列表
struct PluginCategorySettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 目标分类
    let category: PluginCategory

    /// 插件设置存储
    private let settingsStore = AppPluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片
            headerCard
                .padding(24)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 插件列表
                    pluginListCard

                    Spacer()
                }
                .padding(.horizontal, 24)
            }

            AppSettingsStatsBar("共 \(plugins.count) 个插件 · \(enabledCount) 个已启用")
        }
        .onAppear {
            loadPluginStates()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            AppSettingsSection(title: category.displayName, subtitle: "管理「\(category.displayName)」分类下的插件") {}
        }
    }

    // MARK: - Plugin List Card

    private var pluginListCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plugins.enumerated()), id: \.element.instanceLabel) { index, plugin in
                    let pluginType = type(of: plugin)
                    let pluginId = plugin.instanceLabel

                    AppSettingsPluginToggleRow(
                        name: pluginType.displayName,
                        description: pluginType.description(for: .current),
                        icon: pluginType.iconName,
                        isEnabled: Binding(
                            get: { pluginStates[pluginId, default: true] },
                            set: { newValue in
                                pluginStates[pluginId] = newValue
                                settingsStore.setPluginEnabled(pluginId, enabled: newValue)
                                AppLogger.core.info("Plugin '\(pluginId)' is now \(newValue ? "enabled" : "disabled")")
                            }
                        )
                    )

                    if index < plugins.count - 1 {
                        AppSettingsDivider()
                    }
                }

                if plugins.isEmpty {
                    emptyStateContent
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: 16) {
            Text("该分类下暂无可配置的插件")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Data

    /// 获取该分类下的所有可配置插件
    private var plugins: [any SuperPlugin] {
        pluginProvider.getConfigurablePluginsGroupedByCategory()
            .first(where: { $0.category == category })?
            .plugins ?? []
    }

    /// 已启用的插件数量
    private var enabledCount: Int {
        plugins.filter { pluginStates[$0.instanceLabel, default: true] }.count
    }

    /// 加载插件状态
    private func loadPluginStates() {
        var states: [String: Bool] = [:]
        for plugin in plugins {
            let pluginType = type(of: plugin)
            states[pluginType.id] = settingsStore.isPluginEnabled(pluginType.id, defaultEnabled: pluginType.enabledByDefault)
        }
        pluginStates = states
    }
}

// MARK: - Preview

#Preview("Plugin Category - AI") {
    NavigationStack {
        PluginCategorySettingsView(category: .agent)
            .frame(width: 600, height: 500)
    }
    .inRootView()
}
