import SwiftUI
import LumiUI

/// 插件设置视图：控制各个插件的启用/禁用状态
struct PluginSettingsView: View {
    /// 插件设置存储
    private let settingsStore = AppPluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片（固定）
            headerCard
                .padding(24)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .padding(.horizontal, 24)
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
            VStack(spacing: 24) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 48))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                VStack(spacing: 4) {
                    Text("暂无可配置的插件")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text("当插件标记为可配置时，会在此处显示")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
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
        for plugin in pluginProvider.plugins.filter({ type(of: $0).isConfigurable }) {
            let pluginType = type(of: plugin)
            // 使用插件的 enable 静态属性作为未配置时的默认值
            states[pluginType.id] = settingsStore.isPluginEnabled(pluginType.id, defaultEnabled: pluginType.enable)
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
            HStack(spacing: 16) {
                // 图标
                Image(systemName: plugin.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "7C6FFF"))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(hex: "7C6FFF").opacity(0.1))
                    )

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text(plugin.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
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
