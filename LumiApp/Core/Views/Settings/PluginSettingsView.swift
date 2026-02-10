import SwiftUI

/// 插件设置视图：控制各个插件的启用/禁用状态
struct PluginSettingsView: View {
    /// 插件设置存储
    private let settingsStore = PluginSettingsStore.shared

    /// 插件提供者
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                Text("插件管理")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 16)

                Text("启用或禁用应用的插件功能")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                Text("重启应用才能完全生效")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)

                // 插件列表
                ForEach(configurablePlugins) { plugin in
                    PluginToggleRow(
                        plugin: plugin,
                        isEnabled: Binding(
                            get: { pluginStates[plugin.id, default: true] },
                            set: { newValue in
                                pluginStates[plugin.id] = newValue
                                settingsStore.setPluginEnabled(plugin.id, enabled: newValue)
                                print("Plugin '\(plugin.id)' is now \(newValue ? "enabled" : "disabled")")
                            }
                        )
                    )

                    if plugin.id != configurablePlugins.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                // 如果没有可配置的插件
                if configurablePlugins.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无可配置的插件")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text("当插件标记为可配置时，会在此处显示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("插件管理")
        .onAppear {
            loadPluginStates()
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
        HStack(spacing: 16) {
            // 图标
            Image(systemName: plugin.icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(plugin.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 开关
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 8)
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
