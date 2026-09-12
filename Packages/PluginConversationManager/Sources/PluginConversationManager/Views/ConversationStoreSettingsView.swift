import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 会话存储设置视图（v2 复刻版）
///
/// 展示对话列表、日活统计、消息预览与数据目录入口。View 只依赖
/// `ConversationStoreSettingsViewModel`，会话/消息/迁移状态由 Observer 与
/// ViewModel 维护，不再直接访问 ConversationManager 或 MessageManaging。
@MainActor
public struct ConversationStoreSettingsView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ConversationStoreSettingsViewModel

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
                    Label(viewModel.conversationCountLabel, systemImage: "bubble.left.and.bubble.right")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    if viewModel.isMigrationActive {
                        ProgressView()
                            .controlSize(.small)
                    }
#if DEBUG
                    AppButton(L("Open Data Directory"), systemImage: "folder", size: .small) {
                        viewModel.openDataDirectory()
                    }
#endif
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
                    AppSettingsSection(title: L("Overview"), subtitle: L("Read-only summary of the selected conversation")) {
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
                                Text(L("No preview available"))
                                    .font(.callout)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }

                    AppSettingsSection(title: L("Basic Info"), subtitle: L("Core fields stored for this conversation")) {
                        VStack(spacing: 0) {
                            detailRow(title: L("Conversation ID"), icon: "number", value: conversation.id.uuidString, monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Title"), icon: "text.cursor", value: displayTitle(for: conversation))
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Created At"), icon: "calendar.badge.plus", value: formattedDate(conversation.createdAt))
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Updated At"), icon: "calendar.badge.clock", value: formattedDate(conversation.updatedAt))
                        }
                    }

                    AppSettingsSection(title: L("Routing"), subtitle: L("Conversation preferences and context binding")) {
                        VStack(spacing: 0) {
                            detailRow(title: L("Verbosity"), icon: "text.quote", value: conversation.verbosity?.displayName ?? L("Default"))
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Language"), icon: "character.book.closed", value: conversation.language?.displayName ?? L("Default"))
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Automation Level"), icon: conversation.automationLevel?.iconName ?? "gearshape.2", value: conversation.automationLevel?.displayName ?? L("Default"))
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Provider"), icon: "cloud", value: conversation.providerID?.isEmpty == false ? conversation.providerID! : L("Unassigned"), monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Model"), icon: "cpu", value: conversation.modelName?.isEmpty == false ? conversation.modelName! : L("Unassigned"), monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: L("Project Path"), icon: "folder", value: conversation.projectPath?.isEmpty == false ? conversation.projectPath! : L("Unassigned"), monospace: true)
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
        let messages = viewModel.messagesForSelected
        AppSettingsSection(title: L("Messages"), subtitle: String(format: L("Showing %lld of the most recent messages (read-only)"), messages.count)) {
            if messages.isEmpty {
                Text(L("No messages in this conversation"))
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

            Text(message.content.isEmpty ? L("(empty)") : message.content)
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
