import SwiftUI
import LumiUI

/// 输入源插件设置视图
public struct InputSettingsView: View {
    @StateObject private var viewModel = InputSettingsViewModel()

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Input Source", bundle: .module),
            subtitle: LumiPluginLocalization.string("Automatically switch input sources per application.", bundle: .module),
            showHeader: false
        ) {
            AppCard {
                AppSettingsSection(spacing: 12) {
                    AppSettingsToggleRow(
                        LumiPluginLocalization.string("Enable Auto Input Source Switching", bundle: .module),
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
                    title: LumiPluginLocalization.string("Rules", bundle: .module),
                    spacing: 6
                ) {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
                        InputRuleRowView(
                            rule: rule,
                            availableSources: viewModel.availableSources
                        )
                        .contextMenu {
                            Button(LumiPluginLocalization.string("Delete", bundle: .module), role: .destructive) {
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
