import SwiftUI

/// 插件设置视图：控制各个插件的启用/禁用状态
struct PluginSettingsView: View {
    /// 插件设置存储
    private let settingsStore = PluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: PluginVM

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片（固定）
            headerCard
                .padding(DesignTokens.Spacing.lg)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // 插件列表卡片
                    if !configurablePlugins.isEmpty {
                        pluginListCard
                    }

                    // 空状态卡片
                    if configurablePlugins.isEmpty {
                        emptyStateCard
                    }

                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("插件管理")
        .onAppear {
            loadPluginStates()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard {
            GlassSectionHeader(
                icon: "puzzlepiece.extension.fill",
                title: "插件管理",
                subtitle: "启用或禁用应用的插件功能"
            )
        }
    }

    // MARK: - Plugin List Card

    private var pluginListCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(configurablePlugins) { plugin in
                    PluginToggleRow(
                        plugin: plugin,
                        isEnabled: Binding(
                            get: { pluginStates[plugin.id, default: true] },
                            set: { newValue in
                                pluginStates[plugin.id] = newValue
                                settingsStore.setPluginEnabled(plugin.id, enabled: newValue)
                                AppLogger.core.info("Plugin '\(plugin.id)' is now \(newValue ? "enabled" : "disabled")")
                            }
                        )
                    )

                    if plugin.id != configurablePlugins.last?.id {
                        GlassDivider()
                    }
                }
            }
        }
    }

    // MARK: - Empty State Card

    private var emptyStateCard: some View {
        GlassCard {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 48))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("暂无可配置的插件")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text("当插件标记为可配置时，会在此处显示")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xl)
        }
    }

    /// 获取可配置的插件列表（从自动发现的插件中提取）
    private var configurablePlugins: [PluginInfo] {
        pluginProvider.plugins
            .filter { type(of: $0).isConfigurable }
            .map { plugin in
                let pluginType = type(of: plugin)
                return PluginInfo(
                    id: pluginType.id,
                    name: pluginType.displayName,
                    description: pluginType.description,
                    icon: pluginType.iconName,
                    isDeveloperEnabled: { true }
                )
            }
    }

    /// 加载插件状态
    private func loadPluginStates() {
        var states: [String: Bool] = [:]
        for plugin in configurablePlugins {
            states[plugin.id] = settingsStore.isPluginEnabled(plugin.id)
        }
        pluginStates = states
    }
}

/// 插件开关行视图
struct PluginToggleRow: View {
    let plugin: PluginInfo
    @Binding var isEnabled: Bool

    var body: some View {
        GlassRow {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 图标
                Image(systemName: plugin.icon)
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                    )

                // 信息
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(plugin.name)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(plugin.description)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
