import SwiftUI
import LumiUI

/// 插件设置总览视图：展示所有分类的摘要卡片
///
/// 从设置界面侧边栏的各分类子项可以直接进入分类详情页，
/// 此总览页展示所有分类的概览信息，方便用户快速了解插件分布。
struct PluginSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 插件设置存储
    private let settingsStore = AppPluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片（固定）
            headerCard
                .padding(24)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 按分类展示摘要卡片
                    ForEach(groupedPlugins, id: \.category) { group in
                        categorySummaryCard(for: group)
                    }

                    // 空状态卡片
                    if groupedPlugins.isEmpty {
                        emptyStateCard
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }

            AppSettingsStatsBar(
                "共 \(overallTotal) 个插件 · \(overallEnabled) 个已启用 · \(groupedPlugins.count) 个分类"
            )
        }
        .navigationTitle("插件管理")
        .onAppear {
            loadPluginStates()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            AppSettingsSection(title: "插件管理", subtitle: "启用或禁用应用的插件功能。在左侧选择分类查看详情。") {}
        }
    }

    // MARK: - Category Summary Card

    private func categorySummaryCard(for group: (category: PluginCategory, plugins: [any SuperPlugin])) -> some View {
        AppCard {
            HStack(spacing: 16) {
                // 分类图标
                Image(systemName: group.category.systemImage)
                    .font(.appTitle)
                    .foregroundColor(theme.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.appAccentSoftFill)
                    )

                // 分类信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.category.displayName)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text("\(group.plugins.count) 个插件 · \(enabledCount(for: group.plugins) ) 个已启用")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                // 启用率进度环
                AppMiniProgressRing(
                    total: group.plugins.count,
                    enabled: enabledCount(for: group.plugins)
                )
            }
        }
    }

    // MARK: - Empty State Card

    private var emptyStateCard: some View {
        AppCard {
            VStack(spacing: 24) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.appLargeTitle)
                    .foregroundColor(theme.textSecondary)

                VStack(spacing: 4) {
                    Text("暂无可配置的插件")
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text("当插件标记为可配置时，会在此处显示")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Data

    private var overallTotal: Int {
        groupedPlugins.reduce(0) { $0 + $1.plugins.count }
    }

    private var overallEnabled: Int {
        groupedPlugins.reduce(0) { $0 + enabledCount(for: $1.plugins) }
    }

    // MARK: - Data Helpers

    /// 获取按分类分组的可配置插件
    private var groupedPlugins: [(category: PluginCategory, plugins: [any SuperPlugin])] {
        pluginProvider.getConfigurablePluginsGroupedByCategory()
    }

    /// 计算一组插件中已启用的数量
    private func enabledCount(for plugins: [any SuperPlugin]) -> Int {
        plugins.filter { pluginStates[$0.instanceLabel, default: true] }.count
    }

    /// 加载插件状态
    private func loadPluginStates() {
        var states: [String: Bool] = [:]
        for plugin in pluginProvider.plugins.filter({ type(of: $0).isConfigurable }) {
            let pluginType = type(of: plugin)
            // 使用插件的 enable 静态属性作为未配置时的默认值
            states[pluginType.id] = settingsStore.isPluginEnabled(pluginType.id, defaultEnabled: pluginType.enable)
        }
        pluginStates = states
    }
}

// MARK: - Preview

#Preview("Plugin Settings") {
    NavigationStack {
        PluginSettingsView()
            .frame(width: 600, height: 500)
    }
    .inRootView()
}
