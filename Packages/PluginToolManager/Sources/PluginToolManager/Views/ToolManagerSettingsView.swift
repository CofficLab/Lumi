import AgentToolKit
import AppKit
import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具管理器设置视图（复刻旧版 ToolManagerPlugin 的设置体验）。
///
/// 顶部 Tab：Tools（可用工具列表）/ Execution Log（执行日志）/
/// Usage Statistics（调用统计）；右上角可打开数据目录。
struct ToolManagerSettingsView: View {
    @LumiTheme private var theme

    let manager: any ToolManagerProviding
    let store: ProviderToolManager.ToolCallRecordStore?

    @State private var selectedTabID: Tab = .tools
    @State private var groups: [(pluginID: String, tools: [any SuperAgentTool])] = []

    enum Tab: String, Identifiable {
        case tools
        case executionLog
        case toolStats

        var id: String { rawValue }

        var title: String {
            switch self {
            case .tools: "Tools"
            case .executionLog: "Execution Log"
            case .toolStats: "Usage Statistics"
            }
        }

        var icon: String {
            switch self {
            case .tools: "wrench.and.screwdriver"
            case .executionLog: "list.bullet.rectangle.portrait"
            case .toolStats: "chart.bar.xaxis"
            }
        }
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 12) {
                tabBar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task { await reload() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton(.tools)
            if store != nil {
                tabButton(.executionLog)
                tabButton(.toolStats)
            }
            Spacer()
            AppButton(
                "Open Data Directory",
                systemImage: "folder",
                size: .small
            ) {
                openDataDirectory()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .zIndex(1)
    }

    private func tabButton(_ tab: Tab) -> some View {
        AppButton(
            tab.title,
            systemImage: tab.icon,
            style: selectedTabID == tab ? .primary : .secondary,
            size: .small
        ) {
            selectedTabID = tab
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTabID {
        case .tools:
            toolsContent
        case .executionLog:
            if let store {
                ToolCallLogSettingsView(store: store)
            } else {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Execution Log unavailable",
                    description: "Lumi storage is not configured, so tool call records cannot be persisted."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .toolStats:
            if let store {
                ToolCallStatsSettingsView(store: store)
            } else {
                AppEmptyState(
                    icon: "chart.bar.xaxis",
                    title: "Usage Statistics unavailable",
                    description: "Lumi storage is not configured."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Tools

    private var toolsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("\(totalToolCount) tools", systemImage: "wrench.and.screwdriver")
                Spacer()
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if groups.isEmpty {
                        AppEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: "No Tools Registered",
                            description: "No tools are currently registered in the kernel."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(groups, id: \.pluginID) { group in
                            AppSettingSection(title: group.pluginID, titleAlignment: .leading) {
                                LazyVStack(spacing: 0) {
                                    ForEach(group.tools, id: \.name) { tool in
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

    private var totalToolCount: Int {
        groups.reduce(0) { $0 + $1.tools.count }
    }

    // MARK: - Data

    @MainActor
    private func reload() async {
        await Task.yield()
        groups = manager.toolsGroupedByPlugin()
    }

    private func openDataDirectory() {
        let url = store?.directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}

/// 单个工具行：名称 + 描述。
private struct ToolManagerToolRowView: View {
    @LumiTheme private var theme
    let tool: any SuperAgentTool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.appBody)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textPrimary)
                Text(tool.description(for: .chinese))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface)
    }
}
