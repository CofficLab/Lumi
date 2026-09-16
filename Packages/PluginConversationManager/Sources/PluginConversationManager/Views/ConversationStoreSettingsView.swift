import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 会话存储设置视图（v2 复刻版）
///
/// 展示对话列表、日活统计与消息预览。View 只依赖
/// `ConversationStoreSettingsViewModel`，会话/消息/迁移状态由 Observer 与
/// ViewModel 维护，不再直接访问 ConversationManager 或 MessageManaging。
@MainActor
public struct ConversationStoreSettingsView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ConversationStoreSettingsViewModel
    @State private var isTotalCountPopoverPresented = false

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    init(viewModel: ConversationStoreSettingsViewModel) {
        self.viewModel = viewModel
    }
    public var body: some View {
        PluginSettingsScaffold(
            title: L("Conversation Manager"),
            subtitle: L("Browse and inspect stored conversations"),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    if viewModel.isMigrationActive {
                        ProgressView()
                            .controlSize(.small)
                    }
                    totalCountButton
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
            await viewModel.loadInitialIfNeeded()
        }
        .task(id: viewModel.selectedConversationID) {
            await viewModel.loadMessages()
        }
        .onAppear {
            viewModel.seedSelectionIfNeeded()
        }
        .onChange(of: viewModel.conversationIDs) { _, _ in
            viewModel.syncSelectionAfterConversationChange()
        }
    }

    private var conversationActivity: some View {
        AppSettingsSection(
            title: L("Conversation Activity"),
            subtitle: L("Conversations created per day over the last 14 days"),
            spacing: 12
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(L("Daily conversations"), systemImage: "chart.xyaxis.line")
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text(String(format: L("Peak (%lld)"), viewModel.dailyCountSeries.peakCount))
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                ConversationDailyCountChart(series: viewModel.dailyCountSeries)
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

    // MARK: - Total Count

    /// 右上角总数按钮，与 HTTP 日志页保持一致：按钮显示计数，点击展开说明气泡。
    private var totalCountButton: some View {
        AppButton(viewModel.conversationCountDisplay, systemImage: "bubble.left.and.bubble.right", size: .small) {
            isTotalCountPopoverPresented.toggle()
        }
        .accessibilityLabel(L("Total conversations"))
        .accessibilityValue(viewModel.conversationCountDisplay)
        .help(L("Show total conversation details"))
        .popover(isPresented: $isTotalCountPopoverPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Total conversations"))
                    .font(.appBodyEmphasized)

                if let total = viewModel.totalConversationCount {
                    Text(total.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                }

                Text(L("The number of conversations currently stored locally, including child conversations."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingConversations && viewModel.conversations.isEmpty {
                loadingView
            } else if viewModel.conversations.isEmpty {
                AppEmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: L("No conversations")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.conversations) { conversation in
                            conversationRow(conversation)
                                .onAppear {
                                    if conversation.id == viewModel.conversations.last?.id {
                                        Task { await viewModel.loadMoreIfNeeded() }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)

                if viewModel.isLoadingMoreConversations {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 8)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        let isSelected = viewModel.selectedConversationID == conversation.id
        return AppListRow(isSelected: isSelected, action: {
            viewModel.selectConversation(id: conversation.id)
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
        if let conversation = viewModel.selectedConversation {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection(for: conversation)

                    basicInfoSection(for: conversation)

                    routingSection(for: conversation)

                    messagesSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: viewModel.isLoadingConversations ? L("Loading…") : (viewModel.conversations.isEmpty ? L("No conversations") : L("Select a conversation"))
            )
            .overlay {
                if viewModel.isLoadingConversations {
                    loadingView
                }
            }
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    // MARK: - Detail Sections

    /// 概览卡片：与 HTTP 日志详情页一致，标题下先给出说明文案，再放只读摘要。
    private func overviewSection(for conversation: ConversationSummary) -> some View {
        AppSettingSection(title: L("Overview"), titleAlignment: .leading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Read-only summary of the selected conversation"))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle(for: conversation))
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Text(conversation.preview.isEmpty ? L("No preview available") : conversation.preview)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    /// 基本信息：`AppSettingRow` 行式布局，标签在左、取值作为描述在下方，
    /// 右侧只保留复制这类操作按钮。
    private func basicInfoSection(for conversation: ConversationSummary) -> some View {
        AppSettingSection(title: L("Basic Info"), titleAlignment: .leading) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: L("Conversation ID"),
                    description: conversation.id.uuidString,
                    icon: "number"
                ) {
                    copyAction(for: conversation.id.uuidString)
                }

                detailDivider

                AppSettingRow(
                    title: L("Title"),
                    description: displayTitle(for: conversation),
                    icon: "text.cursor"
                ) {
                    EmptyView()
                }

                detailDivider

                AppSettingRow(
                    title: L("Created At"),
                    description: formattedDate(conversation.createdAt),
                    icon: "calendar.badge.plus"
                ) {
                    EmptyView()
                }

                detailDivider

                AppSettingRow(
                    title: L("Updated At"),
                    description: formattedDate(conversation.updatedAt),
                    icon: "calendar.badge.clock"
                ) {
                    EmptyView()
                }
            }
        }
    }

    /// 路由：会话偏好与上下文绑定，取值缺省时回退到占位文案。
    private func routingSection(for conversation: ConversationSummary) -> some View {
        AppSettingSection(title: L("Routing"), titleAlignment: .leading) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: L("Verbosity"),
                    description: conversation.verbosity?.displayName ?? L("Default"),
                    icon: "text.quote"
                ) {
                    EmptyView()
                }

                detailDivider

                AppSettingRow(
                    title: L("Language"),
                    description: conversation.language?.displayName ?? L("Default"),
                    icon: "character.book.closed"
                ) {
                    EmptyView()
                }

                detailDivider

                AppSettingRow(
                    title: L("Automation Level"),
                    description: conversation.automationLevel?.displayName ?? L("Default"),
                    icon: conversation.automationLevel?.iconName ?? "gearshape.2"
                ) {
                    EmptyView()
                }

                detailDivider

                AppSettingRow(
                    title: L("Provider"),
                    description: rowValue(conversation.providerID),
                    icon: "cloud"
                ) {
                    copyAction(for: conversation.providerID)
                }

                detailDivider

                AppSettingRow(
                    title: L("Model"),
                    description: rowValue(conversation.modelName),
                    icon: "cpu"
                ) {
                    copyAction(for: conversation.modelName)
                }

                detailDivider

                AppSettingRow(
                    title: L("Project Path"),
                    description: rowValue(conversation.projectPath),
                    icon: "folder"
                ) {
                    copyAction(for: conversation.projectPath)
                }
            }
        }
    }

    /// 行内分隔：与 HTTP 日志详情页的 `Divider().padding(.vertical, 8)` 保持一致。
    private var detailDivider: some View {
        Divider().padding(.vertical, 8)
    }

    /// 仅对真实存在的取值展示复制按钮，占位文案不可复制。
    @ViewBuilder
    private func copyAction(for value: String?) -> some View {
        if let value, !value.isEmpty {
            AppIconButton(systemImage: "doc.on.doc", size: .compact) {
                LumiPasteboard.copyString(value)
            }
            .help(L("Copy"))
        }
    }

    /// 空字符串与 `nil` 一并视为未设置。
    private func rowValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return L("Unassigned") }
        return value
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesSection: some View {
        let messages = viewModel.messagesForSelected
        AppSettingSection(title: L("Messages"), titleAlignment: .leading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: L("Showing %lld of the most recent messages (read-only)"), messages.count))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 4)

                if messages.isEmpty {
                    Text(L("No messages in this conversation"))
                        .font(.appCallout)
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

            Text(message.content.isEmpty ? L("(empty)") : message.content)
                .font(.appCallout)
                .foregroundStyle(message.isError ? theme.error : theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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

    // MARK: - Formatting

    private func displayTitle(for conversation: ConversationSummary) -> String {
        conversation.displayTitle
    }

    private func formattedListDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var loadingView: some View {
        ProgressView("Loading…")
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageCountLabel(for conversationID: UUID) -> String {
        guard let count = viewModel.messageCounts[conversationID] else {
            return L("Loading…")
        }
        return count == 1 ? L("1 message") : String(format: L("%lld messages"), count)
    }
}
