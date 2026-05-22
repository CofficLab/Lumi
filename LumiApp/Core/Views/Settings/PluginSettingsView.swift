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

            // 底部统计栏
            overallStatsBar
        }
        .navigationTitle("插件管理")
        .onAppear {
            loadPluginStates()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            GlassSectionHeader(
                icon: "puzzlepiece.extension.fill",
                title: "插件管理",
                subtitle: "启用或禁用应用的插件功能。在左侧选择分类查看详情。"
            )
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
                        RoundedRectangle(cornerRadius: 8)
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
                MiniProgressRing(
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
                    .font(.system(size: 48))
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

    // MARK: - Overall Stats Bar

    private var overallStatsBar: some View {
        HStack {
            Spacer()

            let total = groupedPlugins.reduce(0) { $0 + $1.plugins.count }
            let enabled = groupedPlugins.reduce(0) { $0 + enabledCount(for: $1.plugins) }

            Text("共 \(total) 个插件 · \(enabled) 个已启用 · \(groupedPlugins.count) 个分类")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .background(.bar)
    }

    // MARK: - Data

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

// MARK: - Mini Progress Ring

/// 小型进度环，显示启用率
private struct MiniProgressRing: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let total: Int
    let enabled: Int

    init(total: Int, enabled: Int) {
        self.total = total
        self.enabled = enabled
    }

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(enabled) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(theme.appStatusMutedFill, lineWidth: 3)

            // 进度圆环
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // 百分比文字
            Text("\(Int(ratio * 100))%")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.primary)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Plugin Toggle Row

/// 插件开关行视图
struct PluginToggleRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let name: String
    let description: String
    let icon: String
    @Binding var isEnabled: Bool

    init(name: String, description: String, icon: String, isEnabled: Binding<Bool>) {
        self.name = name
        self.description = description
        self.icon = icon
        self._isEnabled = isEnabled
    }

    var body: some View {
        GlassRow {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.appTitle)
                    .foregroundColor(theme.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(theme.appAccentSoftFill)
                    )

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text(description)
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                // 开关
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
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
