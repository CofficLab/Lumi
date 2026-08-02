import AppKit
import Foundation
import LumiUI
import SwiftUI

/// 执行日志视图：展示 ToolCallRecordStore 中的工具调用记录。
///
/// 视觉/交互沿用 NetworkManagerPlugin 的 HTTPExchangeSettingsView：
/// - 左侧 340pt 滚动列表（每条记录一行：状态 + 工具名 + 时间）
/// - 右侧详情面板（参数 / 结果 / 错误 / 耗时 / 风险等级）
/// - 触底分页加载，每页 40 条
@MainActor
public struct ToolCallLogSettingsView: View {
    private let store: ToolCallRecordStore
    @LumiTheme private var theme

    @State private var records: [ToolCallRecordDTO] = []
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var isLoadingMore = false
    @State private var hasMoreRecords = true
    @State private var totalRecordCount: Int?
    @State private var selectedRecordID: String?

    private let pageSize = 40

    public init(store: ToolCallRecordStore) {
        self.store = store
    }

    private var selectedRecord: ToolCallRecordDTO? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 340)
                    .frame(maxHeight: .infinity)

                AppDivider(.vertical)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await reloadAsync()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Label(totalCountLabel, systemImage: "list.bullet.rectangle.portrait")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            AppButton(
                LumiPluginLocalization.string("Refresh", bundle: .module),
                systemImage: "arrow.clockwise",
                size: .small
            ) {
                Task { await reloadAsync() }
            }
            AppButton(
                LumiPluginLocalization.string("Open Data Directory", bundle: .module),
                systemImage: "folder",
                size: .small
            ) {
                NSWorkspace.shared.open(store.directory)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading && records.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: LumiPluginLocalization.string("No tool calls", bundle: .module),
                    description: LumiPluginLocalization.string("Tool executions recorded by Lumi will appear here.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(records) { record in
                            recordRow(record)
                                .onAppear {
                                    if record.id == records.last?.id {
                                        Task { await loadMoreAsync() }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)

                if isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 8)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func recordRow(_ record: ToolCallRecordDTO) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: statusIcon(for: record))
                        .font(.appMicro)
                        .foregroundStyle(statusColor(for: record))
                    Text(record.toolName)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(formattedTime(record.startedAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                if !record.toolDisplayName.isEmpty {
                    Text(record.toolDisplayName)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summarySection(record: selectedRecord)
                    argumentsSection(record: selectedRecord)
                    resultSection(record: selectedRecord)
                }
                .padding(20)
            }
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: LumiPluginLocalization.string("Select a tool call", bundle: .module),
                description: LumiPluginLocalization.string("Choose a record from the list to inspect its arguments and result.", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func summarySection(record: ToolCallRecordDTO) -> some View {
        AppSettingsSection(
            title: LumiPluginLocalization.string("Invocation", bundle: .module),
            subtitle: LumiPluginLocalization.string("Tool identity, timing and outcome", bundle: .module)
        ) {
            VStack(spacing: 0) {
                detailRow(
                    title: LumiPluginLocalization.string("Status", bundle: .module),
                    icon: record.resultIsError ? "exclamationmark.triangle.fill" : "checkmark.circle",
                    iconColor: statusColor(for: record),
                    value: record.resultIsError
                        ? LumiPluginLocalization.string("Failed", bundle: .module)
                        : LumiPluginLocalization.string("Succeeded", bundle: .module)
                )
                AppSettingsDivider()
                detailRow(
                    title: LumiPluginLocalization.string("Tool", bundle: .module),
                    icon: "wrench.and.screwdriver",
                    value: record.toolName,
                    monospace: true
                )
                if !record.toolDisplayName.isEmpty {
                    AppSettingsDivider()
                    detailRow(
                        title: LumiPluginLocalization.string("Description", bundle: .module),
                        icon: "text.alignleft",
                        value: record.toolDisplayName
                    )
                }
                AppSettingsDivider()
                detailRow(
                    title: LumiPluginLocalization.string("Started At", bundle: .module),
                    icon: "calendar",
                    value: formattedDate(record.startedAt)
                )
                if let duration = record.duration {
                    AppSettingsDivider()
                    detailRow(
                        title: LumiPluginLocalization.string("Duration", bundle: .module),
                        icon: "clock",
                        value: formatDuration(duration)
                    )
                }
                if !record.riskLevel.isEmpty {
                    AppSettingsDivider()
                    detailRow(
                        title: LumiPluginLocalization.string("Risk Level", bundle: .module),
                        icon: "shield",
                        value: record.riskLevel.capitalized
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func argumentsSection(record: ToolCallRecordDTO) -> some View {
        AppSettingsSection(
            title: LumiPluginLocalization.string("Arguments", bundle: .module),
            subtitle: LumiPluginLocalization.string("JSON payload decoded from the model", bundle: .module)
        ) {
            JSONPayloadView(rawText: record.argumentsJSON, fallback: "{}")
        }
    }

    @ViewBuilder
    private func resultSection(record: ToolCallRecordDTO) -> some View {
        let title = record.resultIsError
            ? LumiPluginLocalization.string("Error", bundle: .module)
            : LumiPluginLocalization.string("Result", bundle: .module)
        let subtitle = record.resultIsError
            ? LumiPluginLocalization.string("Failure details returned by the tool", bundle: .module)
            : LumiPluginLocalization.string("Tool output returned to the agent loop", bundle: .module)

        AppSettingsSection(title: title, subtitle: subtitle) {
            JSONPayloadView(rawText: record.resultContent, fallback: "<empty>")
        }
    }

    // MARK: - Helpers

    private func detailRow(
        title: String,
        icon: String,
        iconColor: Color? = nil,
        value: String,
        monospace: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label {
                Text(title)
                    .foregroundStyle(theme.textSecondary)
            } icon: {
                if let iconColor {
                    Image(systemName: icon).foregroundStyle(iconColor)
                } else {
                    Image(systemName: icon).foregroundStyle(theme.textSecondary)
                }
            }
            .frame(width: 130, alignment: .leading)

            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .appCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var totalCountLabel: String {
        guard let totalRecordCount else {
            return LumiPluginLocalization.string("Loading...", bundle: .module)
        }
        return "\(totalRecordCount) " + LumiPluginLocalization.string("tool calls", bundle: .module)
    }

    private func reloadAsync() async {
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        defer {
            isReloading = false
            isLoading = false
        }
        await Task.yield()

        let page = await store.fetchPage(limit: pageSize)
        let total = await store.count()
        records = page
        totalRecordCount = total
        hasMoreRecords = page.count == pageSize
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
        }
    }

    private func loadMoreAsync() async {
        guard !isLoading,
              !isLoadingMore,
              hasMoreRecords,
              let last = records.last else { return }

        isLoadingMore = true
        let page = await store.fetchPage(
            limit: pageSize,
            beforeCreatedAt: last.createdAt,
            beforeID: last.id
        )
        records.append(contentsOf: page)
        hasMoreRecords = page.count == pageSize
        isLoadingMore = false
    }

    private func statusText(for record: ToolCallRecordDTO) -> String {
        record.resultIsError
            ? LumiPluginLocalization.string("Error", bundle: .module)
            : LumiPluginLocalization.string("OK", bundle: .module)
    }

    private func statusIcon(for record: ToolCallRecordDTO) -> String {
        record.resultIsError
            ? "exclamationmark.triangle.fill"
            : "checkmark.circle.fill"
    }

    private func statusColor(for record: ToolCallRecordDTO) -> Color {
        record.resultIsError ? .red : .green
    }

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.2fs", seconds)
        } else {
            return String(format: "%.1fm", seconds / 60)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - JSONPayloadView

/// 解析后的 JSON payload 展示块。等宽字体 + 双选可拷贝，长内容走垂直滚动。
@MainActor
private struct JSONPayloadView: View {
    @LumiTheme private var theme

    let rawText: String
    let fallback: String

    @State private var displayText: String?

    var body: some View {
        Group {
            if let displayText {
                codeBlock(displayText)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Decoding...", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            }
        }
        .task(id: rawText) {
            await renderPayload()
        }
    }

    private func renderPayload() async {
        let parsed = await Task.detached(priority: .utility) {
            Self.prettify(rawText) ?? rawText
        }.value

        if parsed.isEmpty {
            displayText = fallback
        } else {
            displayText = parsed
        }
    }

    private func codeBlock(_ text: String) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
                .padding(10)
        }
        .frame(minHeight: 70, maxHeight: 280)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    /// 尝试 prettify JSON。失败时回退到原始字符串，让用户看到工具输出的真实文本。
    private nonisolated static func prettify(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8) else { return nil }
        do {
            let object = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
            let pretty = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            )
            return String(data: pretty, encoding: .utf8) ?? raw
        } catch {
            return nil
        }
    }
}
