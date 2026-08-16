import KernelCore
import LumiUI
import SwiftUI

/// 展示单个插件的启用状态。
///
/// 当前阶段**仅展示**：开关只读反映内核中的有效启用状态（`kernel.isPluginEnabled`），
/// 不执行运行时启停 / 持久化；后续接入 `PluginControlling` 后再开放交互。
/// 不可配置的插件（required / alwaysOn，对应旧版 alwaysOn）展示对应的策略标签。
struct PluginEnableControl: View {
    @LumiTheme private var theme

    let kernel: KernelCoreContainer
    let plugin: any SuperPlugin

    var body: some View {
        Group {
            if plugin.metadata.policy.isConfigurable {
                Toggle(isOn: Binding(
                    get: { kernel.isPluginEnabled(id: plugin.id) },
                    set: { _ in /* 仅展示，暂不响应切换 */ }
                )) {
                    Text(PluginPluginManagerText.enable)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                }
                .toggleStyle(.switch)
                .disabled(true) // 仅展示：开关不可交互
            } else {
                policyTag
            }
        }
    }

    @ViewBuilder
    private var policyTag: some View {
        switch plugin.metadata.policy {
        case .required, .alwaysOn:
            AppTag(
                PluginPluginManagerText.alwaysOn,
                systemImage: "lock.fill",
                style: .accent
            )
        case .enabledByDefault, .disabledByDefault:
            EmptyView()
        }
    }
}
