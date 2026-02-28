import SwiftUI

/// 输入源插件设置视图
struct InputSettingsView: View {
    // MARK: - Properties

    @StateObject private var viewModel = InputSettingsViewModel()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 启用开关
            MystiqueGlassCard {
                Toggle("Enable Auto Input Source Switching", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { _ in viewModel.toggleEnabled() }
                ))
                .toggleStyle(.switch)
            }

            GlassDivider()

            // 添加新规则表单
            MystiqueGlassCard {
                AddRuleFormView(
                    selectedApp: $viewModel.selectedApp,
                    selectedSourceID: $viewModel.selectedSourceID,
                    runningApps: viewModel.runningApps,
                    availableSources: viewModel.availableSources,
                    onAddRule: viewModel.addRule
                )
            }

            GlassDivider()

            // 规则列表或空状态
            rulesContent
        }
        .padding()
        .onAppear {
            viewModel.refreshRunningApps()
        }
    }

    // MARK: - Views

    /// 规则列表内容（空状态或列表）
    @ViewBuilder
    private var rulesContent: some View {
        if viewModel.rules.isEmpty {
            InputRulesEmptyStateView()
        } else {
            List {
                ForEach(viewModel.rules) { rule in
                    InputRuleRowView(
                        rule: rule,
                        availableSources: viewModel.availableSources
                    )
                }
                .onDelete(perform: viewModel.removeRule)
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(InputPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
