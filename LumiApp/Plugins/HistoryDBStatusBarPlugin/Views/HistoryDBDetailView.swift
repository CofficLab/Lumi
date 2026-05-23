import SwiftUI
import LumiUI

struct HistoryDBDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel: HistoryDBBrowserViewModel

    init(chatHistoryVM: AppChatHistoryVM, conversationVM: WindowConversationVM) {
        _viewModel = StateObject(
            wrappedValue: HistoryDBBrowserViewModel(
                chatHistoryVM: chatHistoryVM,
                conversationVM: conversationVM
            )
        )
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "History Database Browser", table: "HistoryDBStatusBar"),
            systemImage: "tablecells"
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                Task { await viewModel.reload() }
            }
            .help(String(localized: "Reload", table: "HistoryDBStatusBar"))
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                modeTabs

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(String(localized: "Loading...", table: "HistoryDBStatusBar"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else {
                    contentView
                }

                footer
            }
            .frame(height: 740)
        }
        .task {
            await viewModel.reload()
        }
        .onMessageSaved { _, _ in
            Task { await viewModel.reload() }
        }
        .onConversationCreated { _ in
            Task { await viewModel.reload() }
        }
        .onConversationUpdated { _ in
            Task { await viewModel.reload() }
        }
        .onConversationDeleted { _ in
            Task { await viewModel.reload() }
        }
    }

    // MARK: - Header

    private var modeTabs: some View {
        HStack(spacing: 0) {
            tabButton(
                title: String(localized: "Messages", table: "HistoryDBStatusBar"),
                icon: "text.bubble",
                mode: .messages
            )

            tabButton(
                title: String(localized: "Conversations", table: "HistoryDBStatusBar"),
                icon: "message.fill",
                mode: .conversations
            )
        }
        .padding(2)
        .appSurface(style: .subtle, cornerRadius: 8)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, icon: String, mode: HistoryDBViewMode) -> some View {
        let isSelected = viewModel.selectedMode == mode

        return Button {
            viewModel.selectedMode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.appMicroEmphasized)
                Text(title)
                    .font(.appCaptionEmphasized)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? theme.primary.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedMode {
        case .messages:
            messagesTable
        case .conversations:
            conversationsContent
        }
    }

    // MARK: - Messages Table

    @ViewBuilder
    private var messagesTable: some View {
        if viewModel.messageRows.isEmpty {
            emptyView
        } else {
            Table(viewModel.messageRows) {
                TableColumn(String(localized: "Conversation", table: "HistoryDBStatusBar")) { row in
                    Text(row.conversationTitle)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 100)

                TableColumn(String(localized: "Role", table: "HistoryDBStatusBar")) { row in
                    Text(row.role)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 60, max: 80)

                TableColumn(String(localized: "Model", table: "HistoryDBStatusBar")) { row in
                    Text(row.model)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 100)

                TableColumn(String(localized: "Tokens", table: "HistoryDBStatusBar")) { row in
                    Text("\(row.tokens)")
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 50, max: 70)

                TableColumn(String(localized: "Timestamp", table: "HistoryDBStatusBar")) { row in
                    HStack(spacing: 4) {
                        Text(row.timestamp, style: .date)
                        Text(row.timestamp, style: .time)
                    }
                    .foregroundColor(theme.textPrimary)
                }
                .width(min: 130)

                TableColumn(String(localized: "Content", table: "HistoryDBStatusBar")) { row in
                    Text(row.contentPreview)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 200)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .background(Color.clear)
        }
    }

    // MARK: - Conversations Content

    @ViewBuilder
    private var conversationsContent: some View {
        if viewModel.conversationRows.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.conversationRows) { row in
                        HistoryConversationCardView(row: row)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    format: String(localized: "Rows: %lld", table: "HistoryDBStatusBar"),
                    viewModel.totalCount
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            Spacer()

            AppButton(String(localized: "Prev", table: "HistoryDBStatusBar"), size: .small) {
                viewModel.previousPage()
            }
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %lld / %lld", table: "HistoryDBStatusBar"),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            AppButton(String(localized: "Next", table: "HistoryDBStatusBar"), size: .small) {
                viewModel.nextPage()
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty

    private var emptyView: some View {
        AppEmptyState(
            icon: "tray",
            title: LocalizedStringKey(String(localized: "No data", table: "HistoryDBStatusBar"))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
