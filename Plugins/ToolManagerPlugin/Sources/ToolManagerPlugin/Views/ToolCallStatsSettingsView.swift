import SwiftUI
import AppKit
import LumiUI
import LumiKernel

/// 工具调用统计设置视图
///
/// 作为 `ToolManagerSettingsView` 下的一个独立 tab，展示每个工具的累计调用次数、
/// 失败次数与平均耗时。数据来自 `ToolCallRecordStore.fetchToolStats()`。
public struct ToolCallStatsSettingsView: View {
    let kernel: LumiKernel
    let toolCallRecordStore: ToolCallRecordStore?

    @State private var toolStats: [ToolStats] = []
    @State private var isLoadingStats = false
    @State private var isReloading = false

    public init(
        kernel: LumiKernel,
        toolCallRecordStore: ToolCallRecordStore?
    ) {
        self.kernel = kernel
        self.toolCallRecordStore = toolCallRecordStore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(statsLabel, systemImage: "chart.bar.xaxis")
            Spacer()
            AppButton(
                LumiPluginLocalization.string("Open Data Directory", bundle: .module),
                systemImage: "folder",
                size: .small
            ) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if toolCallRecordStore == nil {
            AppEmptyState(
                icon: "chart.bar.xaxis",
                title: LumiPluginLocalization.string("Usage Statistics unavailable", bundle: .module),
                description: LumiPluginLocalization.string(
                    "Lumi storage is not configured, so tool call records cannot be aggregated.",
                    bundle: .module
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if isLoadingStats && toolStats.isEmpty {
                    ProgressView(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if toolStats.isEmpty {
                    AppEmptyState(
                        icon: "chart.bar.xaxis",
                        title: LumiPluginLocalization.string("No tool calls yet", bundle: .module),
                        description: LumiPluginLocalization.string(
                            "Once a tool is invoked from a conversation, its call counts and timings will show up here.",
                            bundle: .module
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppSettingSection(title: LumiPluginLocalization.string("Usage Statistics", bundle: .module)) {
                        VStack(spacing: 0) {
                            ForEach(toolStats) { stat in
                                ToolStatsRowView(stats: stat)
                                if stat.id != toolStats.last?.id {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Computed Properties

    private var statsLabel: String {
        if isLoadingStats {
            return LumiPluginLocalization.string("Loading...", bundle: .module)
        }
        let total = toolStats.reduce(0) { $0 + $1.totalCount }
        return "\(total) " + LumiPluginLocalization.string("total calls", bundle: .module)
    }

    // MARK: - Data Loading

    @MainActor
    private func reload() async {
        guard !isReloading else { return }
        guard let service = kernel.toolManager as? ToolManagerService,
              let recordStore = service.recordStore else {
            return
        }
        isReloading = true
        isLoadingStats = true
        defer {
            isReloading = false
            isLoadingStats = false
        }
        await Task.yield()
        toolStats = await recordStore.fetchToolStats()
    }

    // MARK: - Actions

    private func openDataDirectory() {
        guard let storage = kernel.storage else { return }
        let url = storage.pluginDataDirectory(for: "ToolManager")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - ToolStatsRowView

/// 展示单个工具调用统计的行视图。
struct ToolStatsRowView: View {
    let stats: ToolStats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(stats.toolName)
                .font(.appBody)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 16) {
                // 调用次数
                statBadge(
                    value: "\(stats.totalCount)",
                    label: "calls",
                    color: .blue
                )

                // 失败次数
                if stats.errorCount > 0 {
                    statBadge(
                        value: "\(stats.errorCount)",
                        label: "errors",
                        color: .red
                    )
                }

                // 平均耗时
                statBadge(
                    value: formatDuration(stats.averageDuration),
                    label: "avg",
                    color: .secondary
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            return String(format: "%.0fm", seconds / 60)
        }
    }
}
