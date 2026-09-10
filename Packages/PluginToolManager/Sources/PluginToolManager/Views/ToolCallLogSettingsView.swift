import LumiUI
import ProviderToolManager
import SwiftUI

/// 工具调用执行日志：左侧为分页列表，右侧为选中记录的详情。
struct ToolCallLogSettingsView: View {
    @LumiTheme private var theme

    let store: ProviderToolManager.ToolCallRecordStore

    @State private var records: [ToolCallRecord] = []
    @State private var selectedRecordID: String?
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var beforeCreatedAt: Date?
    @State private var beforeID: String?
    private let pageSize = 50

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    private var selectedRecord: ToolCallRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSettingSection(
                title: L("Execution Log"),
                titleAlignment: .leading
            ) {
                AppSettingRow(
                    title: String(format: L("%lld records loaded"), records.count),
                    description: L("Tool executions will appear here once recorded."),
                    icon: "list.bullet.rectangle.portrait"
                ) {
                    AppButton(
                        L("Refresh"),
                        systemImage: "arrow.clockwise",
                        style: .secondary,
                        size: .small
                    ) {
                        Task { await refresh() }
                    }
                }
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)

                AppDivider(.vertical)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 520, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refresh() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading && records.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("Loading..."))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: L("No tool calls recorded"),
                    description: L("Tool executions will appear here once recorded.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(records) { record in
                            recordRow(record)
                                .onAppear {
                                    if record.id == records.last?.id {
                                        Task { await loadMore() }
                                    }
                                }
                        }

                        if hasMore {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func recordRow(_ record: ToolCallRecord) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: record.resultIsError ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.appCaption)
                        .foregroundStyle(record.resultIsError ? theme.error : theme.success)
                    Text(record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(record.resultContent.isEmpty ? record.toolName : record.resultContent)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRecord {
            ToolCallRecordDetailView(record: selectedRecord)
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: L("Select a tool call"),
                description: L("Select a record from the list to inspect its arguments and result.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        beforeCreatedAt = nil
        beforeID = nil
        hasMore = true
        let page = await store.fetchPage(limit: pageSize)
        records = page
        updateCursor(page)
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
        }
        isLoading = false
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

/// 单条工具调用记录详情。
private struct ToolCallRecordDetailView: View {
    @LumiTheme private var theme
    let record: ToolCallRecord

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSettingSection(title: L("Execution Details"), titleAlignment: .leading) {
                    AppMetadataCard {
                        AppMetadataRow(title: L("Tool"), systemImage: "wrench.and.screwdriver") {
                            metadataValue(record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName)
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Status"), systemImage: record.resultIsError ? "xmark.circle" : "checkmark.circle") {
                            AppTag(
                                record.resultIsError ? L("Failed") : L("Success"),
                                systemImage: record.resultIsError ? "xmark" : "checkmark",
                                style: .accent
                            )
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Risk Level"), systemImage: "shield") {
                            metadataValue(record.riskLevel)
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Created At"), systemImage: "calendar") {
                            metadataValue(record.createdAt.formatted(date: .abbreviated, time: .standard))
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Started At"), systemImage: "play.circle") {
                            metadataValue(record.startedAt.formatted(date: .abbreviated, time: .standard))
                        }
                        if let completedAt = record.completedAt {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Completed At"), systemImage: "checkmark.circle") {
                                metadataValue(completedAt.formatted(date: .abbreviated, time: .standard))
                            }
                        }
                        if let duration = record.duration {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Duration"), systemImage: "clock") {
                                metadataValue(String(format: "%.3f s", duration))
                            }
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Conversation"), systemImage: "bubble.left.and.bubble.right") {
                            metadataValue(record.conversationID.uuidString, monospace: true)
                        }
                        if let turnID = record.turnID {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Turn"), systemImage: "arrow.turn.up.right") {
                                metadataValue(turnID.uuidString, monospace: true)
                            }
                        }
                        if let toolCallID = record.toolCallID {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Tool Call ID"), systemImage: "number") {
                                metadataValue(toolCallID, monospace: true)
                            }
                        }
                    }
                }

                payloadSection(title: L("Arguments"), value: record.argumentsJSON, fallback: "{}")
                payloadSection(title: L("Result"), value: record.resultContent, fallback: L("No result content"))
                if let resultJSON = record.resultJSON, !resultJSON.isEmpty {
                    payloadSection(title: L("Result JSON"), value: resultJSON, fallback: "{}")
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
    }

    private func metadataValue(_ value: String, monospace: Bool = false) -> some View {
        Text(value.isEmpty ? "—" : value)
            .font(monospace ? .appMonoCaption : .appCaption)
            .foregroundStyle(theme.textPrimary)
            .textSelection(.enabled)
    }

    private func payloadSection(title: String, value: String, fallback: String) -> some View {
        AppSettingSection(title: title, titleAlignment: .leading) {
            Text(value.isEmpty ? fallback : value)
                .font(.appMonoCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
