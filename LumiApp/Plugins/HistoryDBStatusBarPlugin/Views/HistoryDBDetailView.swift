import SwiftUI
import LumiUI

struct HistoryDBDetailView: View {
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
        VStack(alignment: .leading, spacing: 0) {
            header

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
        .frame(height: 800)
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

    private var header: some View {
        VStack(spacing: 0) {
            // 标题行
            HStack {
                Image(systemName: "tablecells")
                    .font(.system(size: 13))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(String(localized: "History Database Browser", table: "HistoryDBStatusBar"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Reload", table: "HistoryDBStatusBar"))
            }

            GlassDivider()
                .padding(.vertical, 6)

            // Tab 切换
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
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, icon: String, mode: HistoryDBViewMode) -> some View {
        Button {
            viewModel.selectedMode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(viewModel.selectedMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(viewModel.selectedMode == mode ? Color.accentColor : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .width(min: 100)

                TableColumn(String(localized: "Role", table: "HistoryDBStatusBar")) { row in
                    Text(row.role)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .width(min: 60, max: 80)

                TableColumn(String(localized: "Model", table: "HistoryDBStatusBar")) { row in
                    Text(row.model)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .width(min: 100)

                TableColumn(String(localized: "Tokens", table: "HistoryDBStatusBar")) { row in
                    Text("\(row.tokens)")
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .width(min: 50, max: 70)

                TableColumn(String(localized: "Timestamp", table: "HistoryDBStatusBar")) { row in
                    HStack(spacing: 4) {
                        Text(row.timestamp, style: .date)
                        Text(row.timestamp, style: .time)
                    }
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .width(min: 130)

                TableColumn(String(localized: "Content", table: "HistoryDBStatusBar")) { row in
                    Text(row.contentPreview)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
            .font(.system(size: 11))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Spacer()

            Button(String(localized: "Prev", table: "HistoryDBStatusBar")) {
                viewModel.previousPage()
            }
            .font(.system(size: 11))
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %lld / %lld", table: "HistoryDBStatusBar"),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.system(size: 11))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Button(String(localized: "Next", table: "HistoryDBStatusBar")) {
                viewModel.nextPage()
            }
            .font(.system(size: 11))
            .disabled(viewModel.currentPage >= viewModel.totalPages)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
