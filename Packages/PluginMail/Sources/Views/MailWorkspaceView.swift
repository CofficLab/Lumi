import SwiftUI
import LumiUI
import KitMail

/// 邮件工作区：三栏布局（文件夹树 / 邮件列表 / 阅读窗格）。
///
/// 布局自顶向下，空账户/空文件夹/离线均有可见空态。
public struct MailWorkspaceView: View {
    @LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel: MailWorkspaceViewModel
    @State private var selectedFolderPath: String?
    @State private var searchQuery = ""
    @State private var isSearching = false

    private let sessionManager: MailSessionManager
    private let cache: MailCacheService

    public init(
        sessionManager: MailSessionManager,
        cache: MailCacheService
    ) {
        self.sessionManager = sessionManager
        self.cache = cache
        self._viewModel = StateObject(
            wrappedValue: MailWorkspaceViewModel(
                sessionManager: sessionManager,
                cache: cache
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            errorBanner
            if viewModel.accounts.isEmpty {
                noAccountsView
            } else {
                HStack(spacing: 0) {
                    MailFolderSidebarView(
                        accounts: viewModel.accounts,
                        folders: viewModel.folders,
                        selectedAccountID: viewModel.selectedAccountID,
                        selectedFolderPath: selectedFolderPath,
                        unreadCountProvider: { folder in
                            await viewModel.unreadCount(folder: folder.path)
                        },
                        onSelectAccount: { id in
                            Task { await viewModel.selectAccount(id: id) }
                        },
                        onSelectFolder: { folder in
                            selectedFolderPath = folder.path
                            Task { await viewModel.selectFolder(folder) }
                        }
                    )
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                    Divider()

                    MailListView(
                        messages: viewModel.messages,
                        selectedMessage: viewModel.selectedMessage,
                        isSyncing: viewModel.isSyncing,
                        searchQuery: $searchQuery,
                        onSelect: { message in
                            Task { await viewModel.selectMessage(message) }
                        },
                        onRefresh: {
                            Task { await viewModel.refresh() }
                        },
                        onLoadMore: {
                            Task { await viewModel.loadMore() }
                        }
                    )
                    .frame(minWidth: 260, idealWidth: 340, maxWidth: 400)

                    Divider()

                    readerPane
                        .frame(minWidth: 380, idealWidth: 560)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - 错误条

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.appCallout)
                    .foregroundColor(theme.error)
                Text(message)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                AppButton("关闭", style: .secondary, size: .small) {
                    viewModel.errorMessage = nil
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.appListRowBackground)
        }
    }

    // MARK: - 空态

    private var noAccountsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 44))
                .foregroundColor(theme.textTertiary)
            Text("还没有邮件账户")
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
            Text("请到「设置 → 邮件」添加 IMAP/SMTP 账户。")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 阅读窗格

    @ViewBuilder
    private var readerPane: some View {
        if let detail = viewModel.selectedDetail {
            MailReaderView(detail: detail)
        } else if viewModel.selectedMessage != nil {
            VStack {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载正文…")
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 36))
                    .foregroundColor(theme.textTertiary)
                Text("选择一封邮件查看内容")
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
