import KitAgentTool
import AppKit
import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具管理器设置视图。
///
/// 顶部 Tab：Tools（可用工具列表）/ Execution Log（执行日志）/
/// Usage Statistics（调用统计）；右上角可打开数据目录。
struct ToolManagerSettingsView: View {
    let manager: any ToolManagerProviding
    let store: ProviderToolManager.ToolCallRecordStore?

    @State private var selectedTabID: Tab = .tools
    @State private var groups: [(pluginID: String, tools: [any SuperAgentTool])] = []

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    enum Tab: String, Identifiable {
        case tools
        case executionLog
        case toolStats

        var id: String { rawValue }

        var title: String {
            switch self {
            case .tools: LumiPluginLocalization.string("Tools", bundle: .module)
            case .executionLog: LumiPluginLocalization.string("Execution Log", bundle: .module)
            case .toolStats: LumiPluginLocalization.string("Usage Statistics", bundle: .module)
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
                    // The scaffold intentionally disables its outer scroll view
                    // because each tab owns a full-height list. Keep a small
                    // trailing inset so section borders remain fully visible.
                    .padding(.trailing, -12)
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
#if DEBUG
            AppButton(
                L("Open Data Directory"),
                systemImage: "folder",
                style: .warning,
                size: .small
            ) {
                openDataDirectory()
            }
#endif
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
                    title: L("Execution Log unavailable"),
                    description: L("Lumi storage is not configured, so tool call records cannot be persisted.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .toolStats:
            if let store {
                ToolCallStatsSettingsView(store: store)
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
                Label(String(format: L("%lld tools"), totalToolCount), systemImage: "wrench.and.screwdriver")
                Spacer()
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if groups.isEmpty {
                        AppEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: L("No Tools Registered"),
                            description: L("No tools are currently registered in the kernel.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(groups, id: \.pluginID) { group in
                            AppSettingSection(title: group.pluginID, titleAlignment: .leading) {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.tools.enumerated()), id: \.element.name) { index, tool in
                                        if index > 0 {
                                            Divider()
                                                .padding(.vertical, 8)
                                        }
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
    let tool: any SuperAgentTool

    var body: some View {
        AppSettingRow(
            title: tool.name,
            description: tool.description(for: .chinese),
            icon: "wrench.and.screwdriver"
        ) {
            EmptyView()
        }
    }
}
