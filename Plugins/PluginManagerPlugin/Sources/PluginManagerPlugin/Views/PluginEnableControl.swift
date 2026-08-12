import LumiKernel
import LumiUI
import SwiftUI

/// 控制单个插件的启用状态。
///
/// 可配置插件采用乐观更新：用户操作时先立即更新开关，再让内核执行插件生命周期；
/// 操作结束后重新读取内核中的有效状态，以便在生命周期失败时显示内核已回滚的结果。
struct PluginEnableControl: View {
    @LumiTheme private var theme

    let kernel: LumiKernel
    let plugin: LumiPlugin

    @State private var displayedEnabled: Bool
    @State private var isApplying = false

    init(kernel: LumiKernel, plugin: LumiPlugin) {
        self.kernel = kernel
        self.plugin = plugin
        _displayedEnabled = State(initialValue: kernel.pluginManager.effectiveEnabled(for: plugin))
    }

    var body: some View {
        Group {
            if plugin.policy.isConfigurable {
                Toggle(isOn: Binding(
                    get: { displayedEnabled },
                    set: { enabled in
                        applyOptimisticState(enabled)
                    }
                )) {
                    Text(PluginManagerText.string(PluginManagerText.enable))
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                }
                .toggleStyle(.switch)
                .disabled(isApplying)
            } else {
                policyTag
            }
        }
        .onChange(of: plugin.id) { _, _ in
            synchronizeWithKernel()
        }
        .onLumiEnabledPluginsDidChange {
            guard !isApplying else { return }
            synchronizeWithKernel()
        }
    }

    @ViewBuilder
    private var policyTag: some View {
        switch plugin.policy {
        case .alwaysOn:
            AppTag(
                PluginManagerText.string(PluginManagerText.alwaysOn),
                systemImage: "lock.fill",
                style: .accent
            )
        case .disabled:
            AppTag(
                PluginManagerText.string(PluginManagerText.disabled),
                systemImage: "minus.circle"
            )
        default:
            EmptyView()
        }
    }

    private func applyOptimisticState(_ enabled: Bool) {
        guard !isApplying else { return }

        displayedEnabled = enabled
        isApplying = true

        Task { @MainActor in
            await kernel.pluginManager.plugin(ofType: PluginManagerPlugin.self)?
                .setPluginEnabled(kernel: kernel, id: plugin.id, enabled: enabled)

            // setPluginEnabled 会在生命周期失败时回滚；这里始终以最终内核状态为准。
            displayedEnabled = kernel.pluginManager.isPluginEnabled(id: plugin.id)
            isApplying = false
        }
    }

    private func synchronizeWithKernel() {
        displayedEnabled = kernel.pluginManager.isPluginEnabled(id: plugin.id)
    }
}
