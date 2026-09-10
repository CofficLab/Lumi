import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具调用统计，按工具聚合。
///
/// 新版 `ToolCallRecordStore` 未提供聚合接口，这里分页拉取后在本视图内聚合。
struct ToolCallStatsSettingsView: View {
    let store: ProviderToolManager.ToolCallRecordStore

    @State private var stats: [ToolStatEntry] = []
    @State private var totalCount = 0

    var body: some View {
        AppSettingSection(
            title: L("Usage Statistics"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: String(format: L("%lld total calls"), totalCount),
                    description: L("Tool usage statistics will appear here once tools are called."),
                    icon: "chart.bar.xaxis"
                ) {
                    AppButton(
                        L("Refresh"),
                        systemImage: "arrow.clockwise",
                        style: .secondary,
                        size: .small
                    ) {
                        Task { await reload() }
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                            if index > 0 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                            ToolStatRowView(stat: stat)
                        }
                        if stats.isEmpty {
                            AppEmptyState(
                                icon: "chart.bar.xaxis",
                                title: L("No statistics yet"),
                                description: L("Tool usage statistics will appear here once tools are called.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
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

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

private struct ToolStatRowView: View {
    let stat: ToolStatEntry

    var body: some View {
        AppSettingRow(
            title: stat.toolName,
            description: String(format: LumiPluginLocalization.string("%lld errors", bundle: .module), stat.errorCount),
            icon: "wrench.and.screwdriver"
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: LumiPluginLocalization.string("%lld calls", bundle: .module), stat.totalCount))
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                if stat.averageDuration > 0 {
                    Text(String(format: LumiPluginLocalization.string("avg %.2fs", bundle: .module), stat.averageDuration))
                        .font(.appMicro)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
