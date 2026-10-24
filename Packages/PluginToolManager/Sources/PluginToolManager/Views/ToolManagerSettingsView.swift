import KitAgentTool
import LumiUI
import SwiftUI

/// 工具管理器设置视图。
///
/// 顶部 Tab：Tools（可用工具列表）/ Execution Log（执行日志）/
/// Usage Statistics（调用统计）。
/// 只依赖 `ToolManagerViewModel`；工具分组、执行日志与统计状态
/// 全部由 ViewModel 提供。
struct ToolManagerSettingsView: View {
    @ObservedObject var viewModel: ToolManagerViewModel

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                tabBar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.bottom, 16)
        .environment(\.appSettingsCardStyleOverride, .subtle)
        .task {
            switch viewModel.selectedTabID {
            case .tools:
                await viewModel.reloadTools()
            case .executionLog, .toolStats:
                break
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton(.tools)
            if viewModel.hasLogStore {
                tabButton(.executionLog)
                tabButton(.toolStats)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .zIndex(1)
    }

    private func tabButton(_ tab: ToolManagerViewModel.Tab) -> some View {
        AppButton(
            tabTitle(tab),
            systemImage: tabIcon(tab),
            style: viewModel.selectedTabID == tab ? .primary : .secondary,
            size: .small
        ) {
            viewModel.selectTab(tab)
        }
    }

    private func tabTitle(_ tab: ToolManagerViewModel.Tab) -> String {
        switch tab {
        case .tools: L("Tools")
        case .executionLog: L("Execution Log")
        case .toolStats: L("Usage Statistics")
        }
    }

    private func tabIcon(_ tab: ToolManagerViewModel.Tab) -> String {
        switch tab {
        case .tools: "wrench.and.screwdriver"
        case .executionLog: "list.bullet.rectangle.portrait"
        case .toolStats: "chart.bar.xaxis"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.selectedTabID {
        case .tools:
            toolsContent
        case .executionLog:
            if viewModel.hasLogStore {
                ToolCallLogSettingsView(viewModel: viewModel)
            } else {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: L("Execution Log unavailable"),
                    description: L("Lumi storage is not configured, so tool call records cannot be persisted.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .toolStats:
            if viewModel.hasLogStore {
                ToolCallStatsSettingsView(viewModel: viewModel)
            } else {
                AppEmptyState(
                    icon: "chart.bar.xaxis",
                    title: L("Usage Statistics unavailable"),
                    description: L("Lumi storage is not configured.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Tools

    private var toolsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(String(format: L("%lld tools"), viewModel.totalToolCount), systemImage: "wrench.and.screwdriver")
                Spacer()
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.groups.isEmpty {
                        AppEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: L("No Tools Registered"),
                            description: L("No tools are currently registered in the kernel.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(viewModel.groups, id: \.pluginID) { group in
                            AppCard {
                                AppSettingsSection(title: group.pluginID) {
                                    ForEach(Array(group.tools.enumerated()), id: \.element.name) { _, tool in
                                        ToolManagerToolRowView(tool: tool)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 单个工具行：名称 + 描述。
private struct ToolManagerToolRowView: View {
    @LumiTheme private var theme

    let tool: any SuperAgentTool

    var body: some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    Text(tool.description(for: .chinese))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                EmptyView()
            }
        }
    }
}
