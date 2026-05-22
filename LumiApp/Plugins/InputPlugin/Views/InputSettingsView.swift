import SwiftUI
import LumiUI

/// 输入源插件设置视图
struct InputSettingsView: View {
    @StateObject private var viewModel = InputSettingsViewModel()

    var body: some View {
        PluginSettingsScaffold(
            String(localized: "Input Source", table: "Input"),
            subtitle: String(localized: "Automatically switch input sources per application.", table: "Input")
        ) {
            AppCard {
                AppSettingsSection(spacing: 12) {
                    AppSettingsToggleRow(
                        String(localized: "Enable Auto Input Source Switching", table: "Input"),
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
                    title: String(localized: "Rules", table: "Input"),
                    spacing: 6
                ) {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
                        InputRuleRowView(
                            rule: rule,
                            availableSources: viewModel.availableSources
                        )
                        .contextMenu {
                            Button(String(localized: "Delete", table: "Input"), role: .destructive) {
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
    InputSettingsView()
        .inRootView()
        .frame(width: 520, height: 560)
}
