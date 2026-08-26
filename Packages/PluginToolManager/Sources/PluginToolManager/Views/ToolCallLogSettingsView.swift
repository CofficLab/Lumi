import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具调用执行日志，以分页列表展示。
struct ToolCallLogSettingsView: View {
    @LumiTheme private var theme

    let store: ProviderToolManager.ToolCallRecordStore

    @State private var records: [ToolCallRecord] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var beforeCreatedAt: Date?
    @State private var beforeID: String?
    private let pageSize = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(String(format: L("%lld records loaded"), records.count), systemImage: "list.bullet.rectangle.portrait")
                Spacer()
                AppButton(L("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                    Task { await refresh() }
                }
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records) { record in
                        ToolCallRecordRowView(record: record)
                    }
                    if hasMore {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                Task { await loadMore() }
                            }
                    }
                    if records.isEmpty && !isLoading {
                        AppEmptyState(
                            icon: "list.bullet.rectangle.portrait",
                            title: L("No tool calls recorded"),
                            description: L("Tool executions will appear here once recorded.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refresh() }
    }

    @MainActor
    private func refresh() async {
        isLoading = true
        beforeCreatedAt = nil
        beforeID = nil
        hasMore = true
        records = await store.fetchPage(limit: pageSize)
        updateCursor(records)
        isLoading = false
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    @MainActor
    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        let page = await store.fetchPage(
            limit: pageSize,
            beforeCreatedAt: beforeCreatedAt,
            beforeID: beforeID
        )
        records.append(contentsOf: page)
        updateCursor(page)
        isLoading = false
    }

    @MainActor
    private func updateCursor(_ page: [ToolCallRecord]) {
        guard let last = page.last else {
            hasMore = false
            return
        }
        beforeCreatedAt = last.createdAt
        beforeID = last.id
        hasMore = page.count >= pageSize
    }
}

/// 单条工具调用记录行。
private struct ToolCallRecordRowView: View {
    @LumiTheme private var theme
    let record: ToolCallRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: record.resultIsError ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.appCaption)
                    .foregroundStyle(record.resultIsError ? theme.error : theme.success)
                Text(record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName)
                    .font(.appBody)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if let duration = record.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
            }
            if !record.resultContent.isEmpty {
                Text(record.resultContent)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
        }
    }
}
