import SwiftUI
import LumiUI
import LumiCoreKit

public struct DetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel: BrowserViewModel

    public init(historyService: (any HistoryQueryService)?) {
        _viewModel = StateObject(wrappedValue: BrowserViewModel(historyService: historyService))
    }

    public var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "History Database Browser", bundle: .module),
            systemImage: "tablecells"
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                Task { await viewModel.reload() }
            }
            .help(String(localized: "Reload", bundle: .module))
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                modeTabs

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(String(localized: "Loading...", bundle: .module))
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
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessageSaved)) { _ in
            Task { await viewModel.reload() }
        }
    }

    // MARK: - Header

    private var modeTabs: some View {
        HStack(spacing: 0) {
            tabButton(
                title: String(localized: "Messages", bundle: .module),
                icon: "text.bubble",
                mode: .messages
            )

            tabButton(
                title: String(localized: "Conversations", bundle: .module),
                icon: "message.fill",
                mode: .conversations
            )
        }
        .padding(2)
        .appSurface(style: .subtle, cornerRadius: 8)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, icon: String, mode: ViewMode) -> some View {
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
                TableColumn(String(localized: "Conversation", bundle: .module)) { row in
                    Text(row.conversationTitle)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 100)

                TableColumn(String(localized: "Role", bundle: .module)) { row in
                    Text(row.role)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 60, max: 80)

                TableColumn(String(localized: "Model", bundle: .module)) { row in
                    Text(row.model)
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 100)

                TableColumn(String(localized: "Tokens", bundle: .module)) { row in
                    Text("\(row.tokens)")
                        .foregroundColor(theme.textPrimary)
                }
                .width(min: 50, max: 70)

                TableColumn(String(localized: "Timestamp", bundle: .module)) { row in
                    HStack(spacing: 4) {
                        Text(row.timestamp, style: .date)
                        Text(row.timestamp, style: .time)
                    }
                    .foregroundColor(theme.textPrimary)
                }
                .width(min: 130)

                TableColumn(String(localized: "Content", bundle: .module)) { row in
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
                        ConversationCardView(row: row)
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
                    format: String(localized: "Rows: %lld", bundle: .module),
                    viewModel.totalCount
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            Spacer()

            AppButton(String(localized: "Prev", bundle: .module), size: .small) {
                viewModel.previousPage()
            }
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %lld / %lld", bundle: .module),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            AppButton(String(localized: "Next", bundle: .module), size: .small) {
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
            title: LocalizedStringKey(String(localized: "No data", bundle: .module))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
