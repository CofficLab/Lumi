import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具调用统计（复刻旧版 ToolCallStatsSettingsView：按工具聚合）。
///
/// 新版 `ToolCallRecordStore` 未提供聚合接口，这里分页拉取后在本视图内聚合。
struct ToolCallStatsSettingsView: View {
    @LumiTheme private var theme

    let store: ProviderToolManager.ToolCallRecordStore

    @State private var stats: [ToolStatEntry] = []
    @State private var totalCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label("\(totalCount) total calls", systemImage: "chart.bar.xaxis")
                Spacer()
                AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                    Task { await reload() }
                }
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(stats) { stat in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.toolName)
                                    .font(.appBody)
                                    .fontWeight(.medium)
                                    .foregroundStyle(theme.textPrimary)
                                Text("\(stat.errorCount) errors")
                                    .font(.appMicro)
                                    .foregroundStyle(theme.error)
                            }
                            Spacer()
                            Text("\(stat.totalCount) calls")
                                .font(.appBody)
                                .foregroundStyle(theme.textSecondary)
                            if stat.averageDuration > 0 {
                                Text(String(format: "avg %.2fs", stat.averageDuration))
                                    .font(.appMicro)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.surface)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(theme.divider)
                                .frame(height: 0.5)
                        }
                    }
                    if stats.isEmpty {
                        AppEmptyState(
                            icon: "chart.bar.xaxis",
                            title: "No statistics yet",
                            description: "Tool usage statistics will appear here once tools are called."
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    @MainActor
    private func reload() async {
        await Task.yield()
        totalCount = await store.count()

        var all: [ToolCallRecord] = []
        var beforeCreatedAt: Date?
        var beforeID: String?
        var hasMore = true
        while hasMore {
            let page = await store.fetchPage(
                limit: 500,
                beforeCreatedAt: beforeCreatedAt,
                beforeID: beforeID
            )
            all.append(contentsOf: page)
            guard let last = page.last else {
                hasMore = false
                break
            }
            beforeCreatedAt = last.createdAt
            beforeID = last.id
            hasMore = page.count >= 500
        }

        var map: [String: Accumulator] = [:]
        for record in all {
            var acc = map[record.toolName] ?? Accumulator()
            acc.totalCount += 1
            if record.resultIsError { acc.errorCount += 1 }
            if let duration = record.duration { acc.totalDuration += duration }
            map[record.toolName] = acc
        }
        stats = map.map { name, acc in
            ToolStatEntry(
                toolName: name,
                errorCount: acc.errorCount,
                totalCount: acc.totalCount,
                averageDuration: acc.totalCount > 0 ? acc.totalDuration / Double(acc.totalCount) : 0
            )
        }
        .sorted { $0.totalCount > $1.totalCount }
    }
}

/// 单工具统计。
struct ToolStatEntry: Identifiable {
    var id: String { toolName }
    let toolName: String
    let errorCount: Int
    let totalCount: Int
    let averageDuration: Double
}

private struct Accumulator {
    var totalCount = 0
    var errorCount = 0
    var totalDuration: TimeInterval = 0
}
