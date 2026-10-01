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
            AppCard {
                AppSettingsSection(spacing: 12) {
                    AppSettingsToggleRow(
                        pluginLocalization.string("Enable Auto Input Source Switching"),
                        systemImage: "keyboard",
                        isOn: Binding(
                            get: { viewModel.isEnabled },
                            set: { _ in viewModel.toggleEnabled() }
                        )
                    )
                }
            }

            AppCard {
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
            AppCard {
                InputRulesEmptyStateView()
            }
        } else {
            AppCard {
                AppSettingsSection(
                    title: pluginLocalization.string("Rules"),
                    spacing: 6
                ) {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
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
