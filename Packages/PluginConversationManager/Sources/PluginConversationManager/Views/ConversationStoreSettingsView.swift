import AppKit
import LumiUI
import ProviderMessage
import ProviderConversation
import SwiftUI

/// 会话存储设置视图（v2 复刻版）
///
/// 展示对话列表、日活统计、消息预览与数据目录入口。依赖注入的
/// `ConversationManager`（SwiftData 实现）与 `MessageManaging`，
/// 不依赖 KernelLumi。
@MainActor
public struct ConversationStoreSettingsView: View {
    @LumiTheme private var theme
    @ObservedObject private var conversationManager: ConversationManager
    @ObservedObject private var migrationProgress = ConversationMigrationProgressStore.shared

    private let messageManager: (any MessageManaging)?

    @State private var selectedConversationID: UUID?
    @State private var didSeedSelection = false
    @State private var conversations: [LumiConversationSummary] = []
    @State private var totalConversationCount: Int?
    @State private var isLoadingConversations = true
    @State private var isLoadingMoreConversations = false
    @State private var hasMoreConversations = true
    @State private var dailyCountSeries = ConversationDailyCountSeries(points: [])
    @State private var messageCounts: [UUID: Int] = [:]
    @State private var messagesForSelected: [Message] = []

    private let conversationPageSize = 40
    private let messageDisplayLimit = 40

    /// - Parameters:
    ///   - manager: SwiftData 实现的 ConversationManager；nil 时显示不可用占位。
    ///   - messageManager: 消息存储，用于展示会话的消息数/最近消息。
    public init(manager: ConversationManager?, messageManager: (any MessageManaging)? = nil) {
        if let manager {
            self._conversationManager = ObservedObject(wrappedValue: manager)
        } else {
            // 占位 manager：仅当插件初始化失败时出现，理论上不会走到。
            self._conversationManager = ObservedObject(
                wrappedValue: ConversationManager(
                    store: nil,
                    dataDirectory: ConversationStore.defaultDatabaseRootURL
                )
            )
        }
        self.messageManager = messageManager
    }

    private var selectedConversation: LumiConversationSummary? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    private var conversationIDs: [UUID] {
        conversations.map(\.id)
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: "Conversation Manager",
            subtitle: "Browse and inspect stored conversations",
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Label(conversationCountLabel, systemImage: "bubble.left.and.bubble.right")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    if migrationProgress.isActive {
                        ProgressView()
                            .controlSize(.small)
                    }
                    AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                        openDataDirectory()
                    }
                }

                conversationActivity

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
        }
        .task {
            await loadInitialConversations()
        }
        .task(id: selectedConversationID) {
            await loadMessages()
        }
        .onAppear {
            seedSelectionIfNeeded()
        }
        .onChange(of: conversationIDs) { _, _ in
            syncSelectionAfterConversationChange()
        }
    }

    private var conversationActivity: some View {
        AppSettingsSection(
            title: "Conversation Activity",
            subtitle: "Conversations created per day over the last 14 days",
            spacing: 12
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Daily conversations", systemImage: "chart.xyaxis.line")
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text("Peak (\(dailyCountSeries.peakCount))")
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                ConversationDailyCountChart(series: dailyCountSeries)
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoadingConversations && conversations.isEmpty {
                loadingView
            } else if conversations.isEmpty {
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
                                .onAppear {
                                    if conversation.id == conversations.last?.id {
                                        Task { await loadMoreConversationsIfNeeded() }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)

                if isLoadingMoreConversations {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 8)
                }
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

                    Text(messageCountLabel(for: conversation.id))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Text(formattedListDate(conversation.updatedAt))
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
                title: isLoadingConversations ? "Loading…" : (conversations.isEmpty ? "No conversations" : "Select a conversation")
            )
            .overlay {
                if isLoadingConversations {
                    loadingView
                }
            }
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
        AppSettingsSection(title: "Messages", subtitle: "Showing \(messages.count) of the most recent messages (read-only)") {
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

    private func messageRow(_ message: Message) -> some View {
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

    private func roleBadge(_ role: MessageRole) -> some View {
        Text(role.rawValue.capitalized)
            .font(.appMicro.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(roleColor(role))
            .background(roleColor(role).opacity(0.15))
            .clipShape(Capsule())
    }

    private func roleColor(_ role: MessageRole) -> Color {
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

        if let initialSelected = conversationManager.selectedConversationID,
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

    // MARK: - Data

    /// 异步加载当前选中会话的最近一页消息到 `@State`。
    private func loadMessages() async {
        guard let id = selectedConversationID else {
            messagesForSelected = []
            return
        }
        let all = messageManager?.messages(for: id) ?? []
        let loaded = Array(all.suffix(messageDisplayLimit))
        guard selectedConversationID == id else { return }
        messagesForSelected = loaded
    }

    private var conversationCountLabel: String {
        if let totalConversationCount {
            return "\(totalConversationCount) conversations"
        }
        return "Loading conversations…"
    }

    private func loadInitialConversations() async {
        guard conversations.isEmpty, isLoadingConversations else { return }

        isLoadingConversations = true
        async let page = conversationManager.fetchConversationPage(
            limit: conversationPageSize,
            includingChildConversations: true
        )
        async let count = conversationManager.conversationCount(
            projectPath: nil,
            includingChildConversations: true
        )
        async let series = conversationManager.fetchDailyCountSeries()
        let (loaded, total, dailySeries) = await (page, count, series)
        conversations = loaded
        totalConversationCount = total
        dailyCountSeries = dailySeries
        hasMoreConversations = loaded.count == conversationPageSize
        isLoadingConversations = false
        syncSelectionAfterConversationChange()
        await loadMessageCounts(for: loaded)
    }

    private func loadMoreConversationsIfNeeded() async {
        guard !isLoadingConversations,
              !isLoadingMoreConversations,
              hasMoreConversations,
              let last = conversations.last else { return }

        isLoadingMoreConversations = true
        let page = await conversationManager.fetchConversationPage(
            limit: conversationPageSize,
            beforeUpdatedAt: last.lastMessageAt,
            beforeID: last.id,
            includingChildConversations: true
        )
        conversations.append(contentsOf: page)
        hasMoreConversations = page.count == conversationPageSize
        isLoadingMoreConversations = false
        syncSelectionAfterConversationChange()
        await loadMessageCounts(for: page)
    }

    private func loadMessageCounts(for conversations: [LumiConversationSummary]) async {
        guard let messageManager else { return }

        for conversation in conversations where messageCounts[conversation.id] == nil {
            let count = messageManager.messageCount(for: conversation.id)
            messageCounts[conversation.id] = count
        }
    }

    private func messageCountLabel(for conversationID: UUID) -> String {
        guard let count = messageCounts[conversationID] else {
            return "Loading…"
        }
        return count == 1 ? "1 message" : "\(count) messages"
    }

    private func formattedListDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private var loadingView: some View {
        ProgressView("Loading…")
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formatting

    private func displayTitle(for conversation: LumiConversationSummary) -> String {
        conversation.displayTitle
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func openDataDirectory() {
        let url = conversationManager.dataDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
