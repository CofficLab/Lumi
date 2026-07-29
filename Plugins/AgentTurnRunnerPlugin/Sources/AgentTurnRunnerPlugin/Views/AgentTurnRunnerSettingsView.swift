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
            showHeader: false
        ) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)

                AppDivider(.vertical)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 560, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 1)
            }
        }
        .task { await reload() }
    }

    // MARK: - Header (integrated into sidebar header)

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if records.isEmpty {
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
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Label(
                AgentTurnRunnerLocalization.format("Sent Requests", records.count),
                systemImage: "paperplane"
            )
            if let selected = selectedRecord {
                Text(AgentTurnRunnerLocalization.format("Selected: %@", String(selected.conversationID.prefix(8))))
            }
            Spacer()
            AppButton(AgentTurnRunnerLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                Task { await reload() }
            }
            AppButton(AgentTurnRunnerLocalization.string("Clear All"), systemImage: "trash", style: .destructive, size: .small) {
                Task {
                    await AgentTurnRunnerRecordStoreBridge.shared.store?.deleteAll()
                    await reload()
                }
            }
            AppButton(AgentTurnRunnerLocalization.string("Open Data Directory"), systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.background)
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

                    Text(relativeDate(record.createdAt))
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
                    messagesSection(record)
                    toolsSection(record)
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
    private func messagesSection(_ record: AgentTurnRecordDTO) -> some View {
        let messages = decodeMessages(record.messagesJSON)
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Messages"),
            subtitle: AgentTurnRunnerLocalization.format("All %d messages (read-only)", messages.count)
        ) {
            if messages.isEmpty {
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
    private func toolsSection(_ record: AgentTurnRecordDTO) -> some View {
        let tools = decodeTools(record.toolsJSON)
        AppSettingsSection(
            title: AgentTurnRunnerLocalization.string("Tools"),
            subtitle: AgentTurnRunnerLocalization.format("%d tools available to the model", tools.count)
        ) {
            if tools.isEmpty {
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

    private func reload() async {
        let fetched = await AgentTurnRunnerRecordStoreBridge.shared.store?.fetchAll() ?? []
        records = fetched
        if !didSeedSelection {
            didSeedSelection = true
            selectedID = fetched.first?.id
        } else if let selectedID, !fetched.contains(where: { $0.id == selectedID }) {
            self.selectedID = fetched.first?.id
        }
    }

    private func decodeMessages(_ json: String) -> [LumiChatMessage] {
        guard let data = json.data(using: .utf8),
              let messages = try? JSONDecoder().decode([LumiChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    private func decodeTools(_ json: String) -> [[String: String]] {
        guard let data = json.data(using: .utf8),
              let tools = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return tools
    }

    // MARK: - Formatting

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

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
