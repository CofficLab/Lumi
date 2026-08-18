import KernelCore
import LumiUI
import SwiftUI

/// 展示并控制单个插件的启用状态。
///
/// 完美复刻旧版 `PluginManagerPlugin` 的交互体验：关闭 / 打开开关会调用内核
/// `disablePlugin` / `enablePlugin`，完成**运行时启停 + 贡献重建 + 持久化**
/// （启用状态写入原插件数据目录，见 `PluginEnabledStateStore`），并随内核
/// `objectWillChange` 自动刷新 UI。
///
/// 内核的启停会校验策略与依赖：不可配置的插件（required / alwaysOn，
/// 对应旧版 alwaysOn）不渲染开关，只展示对应的策略标签；被其他启用插件依赖
/// 的插件在禁用失败时状态保持不变。
struct PluginEnableControl: View {
    @LumiTheme private var theme

    let kernel: KernelCoreContainer
    let plugin: any SuperPlugin

    /// 切换进行中标记：避免快速连点触发并发启停的竞态。
    @State private var isUpdating = false

    var body: some View {
        Group {
            if plugin.metadata.policy.isConfigurable {
                Toggle(isOn: Binding(
                    get: { kernel.isPluginEnabled(id: plugin.id) },
                    set: { newValue in toggle(newValue) }
                )) {
                    Text(PluginPluginManagerText.enable)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                }
                .toggleStyle(.switch)
                .disabled(isUpdating) // 切换期间短暂禁用，防止连点
            } else {
                policyTag
            }
        }
    }

    /// 触发运行时启停。内核 `enablePlugin` / `disablePlugin` 会执行
    /// `onEnable` / `onDisable`、重建/撤回贡献并持久化到原目录；
    /// 失败时状态保持原样，开关随内核刷新自动回落。
    private func toggle(_ newValue: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        let id = plugin.id
        Task { @MainActor in
            defer { isUpdating = false }
            if newValue {
                try? await kernel.enablePlugin(id: id)
            } else {
                try? await kernel.disablePlugin(id: id)
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
        case .disabled:
            AppTag(
                PluginPluginManagerText.disabledPermanently,
                systemImage: "minus.circle",
                style: .subtle
            )
        case .enabledByDefault, .disabledByDefault:
            EmptyView()
        }
    }
}
