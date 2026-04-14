import SwiftUI

struct HistoryDBDetailView: View {
    @StateObject private var viewModel: HistoryDBBrowserViewModel

    init(chatHistoryVM: ChatHistoryVM, conversationVM: ConversationVM) {
        _viewModel = StateObject(
            wrappedValue: HistoryDBBrowserViewModel(
                chatHistoryVM: chatHistoryVM,
                conversationVM: conversationVM
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.isLoading {
                ProgressView(String(localized: "Loading...", table: "HistoryDBStatusBar"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentTable
                    .environment(\.colorScheme, .light)
                    .foregroundStyle(Color.black)
                    .padding(8)
                    .background(Color.white.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            footer
        }
        .frame(minHeight: 420)
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

    private var header: some View {
        HStack {
            Image(systemName: "tablecells")
                .font(.system(size: 15))
            Text(String(localized: "History Database Browser", table: "HistoryDBStatusBar"))
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Picker("", selection: $viewModel.selectedMode) {
                Text(String(localized: "Message List", table: "HistoryDBStatusBar"))
                    .tag(HistoryDBViewMode.messages)
                Text(String(localized: "Conversation List", table: "HistoryDBStatusBar"))
                    .tag(HistoryDBViewMode.conversations)
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Reload", table: "HistoryDBStatusBar"))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var contentTable: some View {
        switch viewModel.selectedMode {
        case .messages:
            if viewModel.messageRows.isEmpty {
                emptyView
            } else {
                Table(viewModel.messageRows) {
                    TableColumn(String(localized: "Message ID", table: "HistoryDBStatusBar")) { row in
                        Text(row.id.uuidString)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                    }
                    .width(min: 200)

                    TableColumn(String(localized: "Conversation", table: "HistoryDBStatusBar"), value: \.conversationTitle)
                        .width(min: 120)

                    TableColumn(String(localized: "Role", table: "HistoryDBStatusBar"), value: \.role)
                        .width(min: 70, max: 90)

                    TableColumn(String(localized: "Model", table: "HistoryDBStatusBar"), value: \.model)
                        .width(min: 120)

                    TableColumn(String(localized: "Tokens", table: "HistoryDBStatusBar")) { row in
                        Text("\(row.tokens)")
                    }
                    .width(min: 60, max: 80)

                    TableColumn(String(localized: "Timestamp", table: "HistoryDBStatusBar")) { row in
                        Text(row.timestamp, style: .date)
                        + Text(" ")
                        + Text(row.timestamp, style: .time)
                    }
                    .width(min: 150)

                    TableColumn(String(localized: "Content", table: "HistoryDBStatusBar"), value: \.contentPreview)
                        .width(min: 250)
                }
            }

        case .conversations:
            if viewModel.conversationRows.isEmpty {
                emptyView
            } else {
                Table(viewModel.conversationRows) {
                    TableColumn(String(localized: "Conversation ID", table: "HistoryDBStatusBar")) { row in
                        Text(row.id.uuidString)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                    }
                    .width(min: 200)

                    TableColumn(String(localized: "Title", table: "HistoryDBStatusBar"), value: \.title)
                        .width(min: 200)

                    TableColumn(String(localized: "Project", table: "HistoryDBStatusBar"), value: \.projectId)
                        .width(min: 180)

                    TableColumn(String(localized: "Created At", table: "HistoryDBStatusBar")) { row in
                        Text(row.createdAt, style: .date)
                        + Text(" ")
                        + Text(row.createdAt, style: .time)
                    }
                    .width(min: 150)

                    TableColumn(String(localized: "Updated At", table: "HistoryDBStatusBar")) { row in
                        Text(row.updatedAt, style: .date)
                        + Text(" ")
                        + Text(row.updatedAt, style: .time)
                    }
                    .width(min: 150)

                    TableColumn(String(localized: "Messages", table: "HistoryDBStatusBar")) { row in
                        Text("\(row.messageCount)")
                    }
                    .width(min: 70, max: 90)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    format: String(localized: "Rows: %lld", table: "HistoryDBStatusBar"),
                    viewModel.totalCount
                )
            )
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Spacer()

            Button(String(localized: "Prev", table: "HistoryDBStatusBar")) {
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
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Button(String(localized: "Next", table: "HistoryDBStatusBar")) {
                viewModel.nextPage()
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text(String(localized: "No data", table: "HistoryDBStatusBar"))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
