import Foundation
import AppKit
import LumiKernel
import LumiUI
import SwiftUI

/// 设置界面:展示每次「发出的请求」详情。
///
/// 参考 ConversationStorePlugin 提供的设置视图布局(Sidebar + Detail),
/// 数据来自 `AgentTurnRecordStore`(SwiftData 持久化)。
@MainActor
public struct AgentTurnRunnerSettingsView: View {
    @ObservedObject private var kernel: LumiKernel
    @LumiTheme private var theme

    @State private var records: [AgentTurnRecordDTO] = []
    @State private var selectedID: String?
    @State private var didSeedSelection = false
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var isLoadingMore = false
    @State private var hasMoreRecords = true
    @State private var totalRecordCount: Int?
    @State private var dailyCountSeries = AgentTurnDailyCountSeries(points: [])
    @State private var decodedMessages: [LumiChatMessage] = []
    @State private var decodedTools: [[String: String]] = []
    @State private var isLoadingDetailPayload = false

    private let pageSize = 40

    public init(kernel: LumiKernel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
    }

    private var selectedRecord: AgentTurnRecordDTO? {
        guard let selectedID else { return nil }
        return records.first { $0.id == selectedID }
    }

    private var sortedRecords: [AgentTurnRecordDTO] {
        records.sorted { $0.createdAt > $1.createdAt }
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: AgentTurnRunnerLocalization.string("Agent Turn Runner"),
            subtitle: AgentTurnRunnerLocalization.string("Inspect all LLM requests sent by Lumi"),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Text(totalRecordLabel)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    AppButton(AgentTurnRunnerLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                        Task { await reload() }
                    }
                    AppButton(AgentTurnRunnerLocalization.string("Clear All"), systemImage: "trash", style: .destructive, size: .small) {
                        Task { await clearAll() }
                    }
                    AppButton(AgentTurnRunnerLocalization.string("Open Data Directory"), systemImage: "folder", size: .small) {
                        openDataDirectory()
                    }
                }

                requestActivity

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 360)
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
        }
        .task { await reload() }
        .task(id: selectedID) { await loadDetailPayload() }
    }

    private var requestActivity: some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Request Activity"),
            subtitle: AgentTurnRunnerLocalization.string("Sent LLM requests per day over the last 14 days"),
            spacing: 12
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(AgentTurnRunnerLocalization.string("Daily sent requests"), systemImage: "chart.xyaxis.line")
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text("Peak (\(dailyCountSeries.peakCount))")
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                AgentTurnDailyCountChart(series: dailyCountSeries)
                    .frame(height: 132)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.divider, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Header (integrated into sidebar header)

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading && records.isEmpty {
                ProgressView(AgentTurnRunnerLocalization.string("Loading..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "paperplane",
                    title: AgentTurnRunnerLocalization.string("No sent requests")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sortedRecords) { record in
                            recordRow(record)
                                .onAppear {
                                    if record.id == sortedRecords.last?.id {
                                        Task { await loadMore() }
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

    private func recordRow(_ record: AgentTurnRecordDTO) -> some View {
        let isSelected = selectedID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedID = record.id
            didSeedSelection = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.model.isEmpty
                        ? AgentTurnRunnerLocalization.string("Unknown model")
                        : record.model)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(formattedDate(record.createdAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Text(AgentTurnRunnerLocalization.format("%d messages · %d tools", record.messagesCount, record.toolsCount))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                if !record.systemPrompt.isEmpty {
                    Text(record.systemPrompt)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let record = selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection(record)
                    requestInfoSection(record)
                    systemPromptSection(record)
                    messagesSection(record, messages: decodedMessages)
                    toolsSection(record, tools: decodedTools)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "paperplane",
                title: records.isEmpty
                    ? AgentTurnRunnerLocalization.string("No sent requests")
                    : AgentTurnRunnerLocalization.string("Select a request")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    // MARK: - Overview Section

    @ViewBuilder
    private func overviewSection(_ record: AgentTurnRecordDTO) -> some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Overview"),
            subtitle: AgentTurnRunnerLocalization.string("Read-only summary of the sent request")
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(record.model.isEmpty
                    ? AgentTurnRunnerLocalization.string("Unknown model")
                    : record.model)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Text(AgentTurnRunnerLocalization.format("Sent at %@", formattedDate(record.createdAt)))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Request Info Section

    @ViewBuilder
    private func requestInfoSection(_ record: AgentTurnRecordDTO) -> some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Request Info"),
            subtitle: AgentTurnRunnerLocalization.string("Core fields captured for this request")
        ) {
            VStack(spacing: 0) {
                detailRow(
                    title: AgentTurnRunnerLocalization.string("Conversation ID"),
                    icon: "number",
                    value: record.conversationID,
                    monospace: true
                )
                Divider().padding(.vertical, 8)
                detailRow(
                    title: AgentTurnRunnerLocalization.string("Provider"),
                    icon: "cloud",
                    value: record.providerID?.isEmpty == false ? record.providerID! : AgentTurnRunnerLocalization.string("Unknown"),
                    monospace: true
                )
                Divider().padding(.vertical, 8)
                detailRow(
                    title: AgentTurnRunnerLocalization.string("Model"),
                    icon: "cpu",
                    value: record.model.isEmpty ? AgentTurnRunnerLocalization.string("Unknown") : record.model,
                    monospace: true
                )
                Divider().padding(.vertical, 8)
                detailRow(
                    title: AgentTurnRunnerLocalization.string("Sent At"),
                    icon: "calendar.badge.clock",
                    value: formattedDate(record.createdAt)
                )
                Divider().padding(.vertical, 8)
                detailRow(
                    title: AgentTurnRunnerLocalization.string("Image Attachments"),
                    icon: "photo",
                    value: "\(record.imageAttachmentsCount)"
                )
                Divider().padding(.vertical, 8)
                detailRow(
                    title: AgentTurnRunnerLocalization.string("File Attachments"),
                    icon: "doc",
                    value: "\(record.fileAttachmentsCount)"
                )
            }
        }
    }

    // MARK: - System Prompt

    @ViewBuilder
    private func systemPromptSection(_ record: AgentTurnRecordDTO) -> some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("System Prompt"),
            subtitle: AgentTurnRunnerLocalization.string("Merged system message (role = system)")
        ) {
            if record.systemPrompt.isEmpty {
                Text(AgentTurnRunnerLocalization.string("No system prompt in this request"))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ScrollView {
                    Text(record.systemPrompt)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private func messagesSection(_ record: AgentTurnRecordDTO, messages: [LumiChatMessage]) -> some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Messages"),
            subtitle: AgentTurnRunnerLocalization.format("All %d messages (read-only)", messages.count)
        ) {
            if isLoadingDetailPayload {
                ProgressView(AgentTurnRunnerLocalization.string("Loading..."))
            } else if messages.isEmpty {
                Text(AgentTurnRunnerLocalization.string("No messages in this request"))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        messageRow(message)
                    }
                }
            }
        }
    }

    private func messageRow(_ message: LumiChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                roleBadge(message.role)
                Spacer(minLength: 0)
                Text(formattedDate(message.createdAt))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
            }

            Text(message.content.isEmpty ? AgentTurnRunnerLocalization.string("(empty)") : message.content)
                .font(.callout)
                .foregroundStyle(message.isError ? Color.red : theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(theme.divider.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func roleBadge(_ role: LumiChatMessageRole) -> some View {
        Text(role.rawValue.capitalized)
            .font(.appMicro.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(roleColor(role))
            .background(roleColor(role).opacity(0.15))
            .clipShape(Capsule())
    }

    private func roleColor(_ role: LumiChatMessageRole) -> Color {
        switch role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .purple
        case .tool: return .orange
        case .error: return .red
        case .status: return .gray
        }
    }

    // MARK: - Tools

    @ViewBuilder
    private func toolsSection(_ record: AgentTurnRecordDTO, tools: [[String: String]]) -> some View {
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Tools"),
            subtitle: AgentTurnRunnerLocalization.format("%d tools available to the model", tools.count)
        ) {
            if isLoadingDetailPayload {
                ProgressView(AgentTurnRunnerLocalization.string("Loading..."))
            } else if tools.isEmpty {
                Text(AgentTurnRunnerLocalization.string("No tools in this request"))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(tools.indices, id: \.self) { index in
                        let tool = tools[index]
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(tool["name"] ?? AgentTurnRunnerLocalization.string("unknown"))
                                    .font(.appCaptionEmphasized)
                                    .foregroundStyle(theme.textPrimary)
                                Spacer(minLength: 0)
                                Text("#\(index + 1)")
                                    .font(.appMicro)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            if let description = tool["description"], !description.isEmpty {
                                Text(description)
                                    .font(.callout)
                                    .foregroundStyle(theme.textSecondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.divider.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadDetailPayload() async {
        guard let selectedID,
              let record = records.first(where: { $0.id == selectedID }) else {
            decodedMessages = []
            decodedTools = []
            isLoadingDetailPayload = false
            return
        }

        isLoadingDetailPayload = true
        let messagesJSON = record.messagesJSON
        let toolsJSON = record.toolsJSON
        async let messages = Task.detached(priority: .utility) {
            AgentTurnRecordPayloadDecoder.messages(from: messagesJSON)
        }.value
        async let tools = Task.detached(priority: .utility) {
            AgentTurnRecordPayloadDecoder.tools(from: toolsJSON)
        }.value
        let (loadedMessages, loadedTools) = await (messages, tools)
        guard self.selectedID == selectedID else { return }
        decodedMessages = loadedMessages
        decodedTools = loadedTools
        isLoadingDetailPayload = false
    }

    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        defer {
            isReloading = false
            isLoading = false
        }

        await Task.yield()
        guard let store = AgentTurnRunnerRecordStoreBridge.shared.store else {
            records = []
            totalRecordCount = 0
            hasMoreRecords = false
            return
        }

        async let fetched = store.fetchPage(limit: pageSize)
        async let count = store.count()
        async let series = store.fetchDailyCountSeries()
        let (page, total, dailySeries) = await (fetched, count, series)
        records = page
        totalRecordCount = total
        dailyCountSeries = dailySeries
        hasMoreRecords = page.count == pageSize
        updateSelectionIfNeeded(using: page)
    }

    private func loadMore() async {
        guard !isLoading,
              !isLoadingMore,
              hasMoreRecords,
              let last = records.last,
              let store = AgentTurnRunnerRecordStoreBridge.shared.store else { return }

        isLoadingMore = true
        let page = await store.fetchPage(
            limit: pageSize,
            beforeCreatedAt: last.createdAt,
            beforeID: last.id
        )
        records.append(contentsOf: page)
        hasMoreRecords = page.count == pageSize
        isLoadingMore = false
        updateSelectionIfNeeded(using: records)
    }

    private func clearAll() async {
        await AgentTurnRunnerRecordStoreBridge.shared.store?.deleteAll()
        await reload()
    }

    private func updateSelectionIfNeeded(using availableRecords: [AgentTurnRecordDTO]) {
        if !didSeedSelection {
            didSeedSelection = true
            selectedID = availableRecords.first?.id
        } else if let selectedID, !availableRecords.contains(where: { $0.id == selectedID }) {
            self.selectedID = availableRecords.first?.id
        }
    }

    private var totalRecordLabel: String {
        guard let totalRecordCount else {
            return AgentTurnRunnerLocalization.string("Loading...")
        }
        return AgentTurnRunnerLocalization.format("Sent Requests", totalRecordCount)
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func openDataDirectory() {
        let url = AgentTurnRunnerRecordStoreBridge.shared.dataDirectory
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
