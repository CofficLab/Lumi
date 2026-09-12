import LumiUI
import SwiftUI

/// 展示并控制单个插件的启用状态。
///
/// 状态和启停操作全部通过 `PluginManagementViewModel` 完成；Provider 事件由
/// `PluginManagementObserver` 回写 VM 后，Toggle 自动得到最新状态。
struct PluginEnableControl: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: PluginManagementViewModel
    let pluginID: String

    init(viewModel: PluginManagementViewModel, pluginID: String) {
        self.viewModel = viewModel
        self.pluginID = pluginID
    }

    var body: some View {
        Group {
            if selectedPlugin.metadata.policy.isConfigurable {
                Toggle(isOn: Binding(
                    get: { selectedPlugin.isEnabled },
                    set: { viewModel.setEnabled($0, for: pluginID) }
                )) {
                    Text(PluginPluginManagerText.enable)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                }
                .toggleStyle(.switch)
                .disabled(viewModel.isUpdating(pluginID: pluginID))
            } else {
                policyTag
            }
        }
    }

    @ViewBuilder
    private var policyTag: some View {
        switch selectedPlugin.metadata.policy {
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

    private var selectedPlugin: PluginManagementItem {
        guard let selectedPlugin = viewModel.plugins.first(where: { $0.id == pluginID }) else {
            preconditionFailure("PluginEnableControl requires a valid plugin id")
        }
        return selectedPlugin
    }
}
