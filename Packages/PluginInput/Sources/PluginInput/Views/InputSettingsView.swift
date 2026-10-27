import SwiftUI
import LumiUI

/// 输入源插件设置视图
public struct InputSettingsView: View {
    @ObservedObject private var viewModel: InputSettingsViewModel

    init(viewModel: InputSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Input Source"),
            subtitle: pluginLocalization.string("Automatically switch input sources per application."),
            showHeader: false
        ) {
            AppSettingSection(title: nil, titleAlignment: .leading) {
                AppSettingToggleRow(
                    pluginLocalization.string("Enable Auto Input Source Switching"),
                    icon: "keyboard",
                    isOn: Binding(
                        get: { viewModel.isEnabled },
                        set: { _ in viewModel.toggleEnabled() }
                    )
                )
            }

            AppSettingSection(title: nil, titleAlignment: .leading) {
                AddRuleFormView(
                    selectedApp: $viewModel.selectedApp,
                    selectedSourceID: $viewModel.selectedSourceID,
                    runningApps: viewModel.runningApps,
                    availableSources: viewModel.availableSources,
                    onAddRule: viewModel.addRule
                )
            }

            rulesContent
        }
        .onAppear {
            viewModel.refreshRunningApps()
        }
    }

    @ViewBuilder
    private var rulesContent: some View {
        if viewModel.rules.isEmpty {
            AppSettingSection(title: nil, titleAlignment: .leading) {
                InputRulesEmptyStateView()
            }
        } else {
            AppSettingSection(
                title: pluginLocalization.string("Rules"),
                titleAlignment: .leading
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
                        if index > 0 {
                            Divider()
                                .padding(.vertical, 8)
                        }

                        InputRuleRowView(
                            rule: rule,
                            availableSources: viewModel.availableSources
                        )
                        .contextMenu {
                            Button(pluginLocalization.string("Delete"), role: .destructive) {
                                viewModel.removeRule(at: IndexSet(integer: index))
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("App") {
    InputSettingsView(viewModel: InputSettingsViewModel())
        .inRootView()
        .frame(width: 520, height: 560)
}
