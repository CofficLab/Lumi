import Foundation
import AppKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public struct ConversationStoreSettingsView: View {
    @ObservedObject private var kernel: LumiKernel
    @LumiTheme private var theme

    @State private var selectedConversationID: UUID?
    @State private var didSeedSelection = false

    public init(kernel: LumiKernel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
    }

    private var conversations: [LumiConversationSummary] {
        (kernel.conversations?.conversations ?? [])
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var selectedConversation: LumiConversationSummary? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    private var messagesForSelected: [LumiChatMessage] {
        guard let id = selectedConversationID else { return [] }
        return kernel.messageManager?.displayMessages(for: id) ?? []
    }

    private var conversationIDs: [UUID] {
        conversations.map(\.id)
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            seedSelectionIfNeeded()
        }
        .onChange(of: conversationIDs) { _, _ in
            syncSelectionAfterConversationChange()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(conversations.count) conversations", systemImage: "bubble.left.and.bubble.right")
            if let selectedConversation {
                Text("Selected: \(displayTitle(for: selectedConversation))")
            }
            Spacer()
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if conversations.isEmpty {
                AppEmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "No conversations"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(conversations) { conversation in
                            conversationRow(conversation)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func conversationRow(_ conversation: LumiConversationSummary) -> some View {
        let isSelected = selectedConversationID == conversation.id
        return AppListRow(isSelected: isSelected, action: {
            selectedConversationID = conversation.id
            didSeedSelection = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayTitle(for: conversation))
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(relativeDate(conversation.updatedAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Text(conversation.preview.isEmpty ? "No preview available" : conversation.preview)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let conversation = selectedConversation {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppSettingsSection(title: "Overview", subtitle: "Read-only summary of the selected conversation") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(displayTitle(for: conversation))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(2)

                            if !conversation.preview.isEmpty {
                                Text(conversation.preview)
                                    .font(.callout)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(4)
                            } else {
                                Text("No preview available")
                                    .font(.callout)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }

                    AppSettingsSection(title: "Basic Info", subtitle: "Core fields stored for this conversation") {
                        VStack(spacing: 0) {
                            detailRow(title: "Conversation ID", icon: "number", value: conversation.id.uuidString, monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Title", icon: "text.cursor", value: displayTitle(for: conversation))
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Created At", icon: "calendar.badge.plus", value: formattedDate(conversation.createdAt))
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Updated At", icon: "calendar.badge.clock", value: formattedDate(conversation.updatedAt))
                        }
                    }

                    AppSettingsSection(title: "Routing", subtitle: "Conversation preferences and context binding") {
                        VStack(spacing: 0) {
                            detailRow(title: "Verbosity", icon: "text.quote", value: conversation.verbosity?.displayName ?? "Default")
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Language", icon: "character.book.closed", value: conversation.language?.displayName ?? "Default")
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Automation Level", icon: conversation.automationLevel?.iconName ?? "gearshape.2", value: conversation.automationLevel?.displayName ?? "Default")
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Provider", icon: "cloud", value: conversation.providerID?.isEmpty == false ? conversation.providerID! : "Unassigned", monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Model", icon: "cpu", value: conversation.modelName?.isEmpty == false ? conversation.modelName! : "Unassigned", monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Project Path", icon: "folder", value: conversation.projectPath?.isEmpty == false ? conversation.projectPath! : "Unassigned", monospace: true)
                        }
                    }

                    messagesSection
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: conversations.isEmpty ? "No conversations" : "Select a conversation"
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

    // MARK: - Messages

    @ViewBuilder
    private var messagesSection: some View {
        let messages = messagesForSelected
        AppSettingsSection(title: "Messages", subtitle: "All \(messages.count) messages in this conversation (read-only)") {
            if messages.isEmpty {
                Text("No messages in this conversation")
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

            Text(message.content.isEmpty ? "(empty)" : message.content)
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

    // MARK: - Selection

    private func seedSelectionIfNeeded() {
        guard !didSeedSelection else { return }
        didSeedSelection = true

        if let initialSelected = kernel.conversations?.selectedConversationID,
           conversations.contains(where: { $0.id == initialSelected }) {
            selectedConversationID = initialSelected
        } else {
            selectedConversationID = conversations.first?.id
        }
    }

    private func syncSelectionAfterConversationChange() {
        if !didSeedSelection {
            seedSelectionIfNeeded()
            return
        }

        guard let selectedConversationID else {
            selectedConversationID = conversations.first?.id
            return
        }

        guard conversations.contains(where: { $0.id == selectedConversationID }) else {
            self.selectedConversationID = conversations.first?.id
            return
        }
    }

    // MARK: - Formatting

    private func displayTitle(for conversation: LumiConversationSummary) -> String {
        conversation.displayTitle
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func openDataDirectory() {
        let url = kernel.conversations?.dataDirectory
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
