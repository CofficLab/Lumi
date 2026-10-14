import SwiftUI
import LumiUI
import KitMail

/// 邮件账户设置页：账户列表 + 添加/编辑入口。
///
/// 布局遵循 settings-ui 规范：`PluginSettingsScaffold` + `AppCard` +
/// `AppSettings*Row`，不使用 `Form`。
public struct MailSettingsView: View {
    @LumiTheme private var theme: any LumiUITheme

    private let sessionManager: MailSessionManager

    /// 当前展示的编辑草稿（非 nil 时展示表单）。
    @State private var editingDraft: MailAccountDraft?
    /// 正在编辑的账户 id（新增为 nil）。
    @State private var editingAccountID: UUID?
    @State private var accounts: [MailAccountConfig] = []
    /// 连接测试中的账户 id（展示进度）。
    @State private var testingAccountID: UUID?
    @State private var errorMessage: String?

    public init(sessionManager: MailSessionManager) {
        self.sessionManager = sessionManager
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Mail"),
            subtitle: "IMAP/SMTP 账户：连接、撰写、搜索与 Agent 工具。",
            showHeader: true
        ) {
            if editingDraft != nil {
                formCard
            } else {
                accountListCard
                addCard
            }
        }
        .task {
            reloadAccounts()
        }
    }

    // MARK: - 账户列表

    private var accountListCard: some View {
        AppCard {
            AppSettingsSection(
                title: "账户",
                spacing: 12
            ) {
                if accounts.isEmpty {
                    Text("还没有邮件账户。点击下方「添加账户」开始配置。")
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                } else {
                    ForEach(accounts) { account in
                        accountRow(account)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                }
            }
        }
    }

    private func accountRow(_ account: MailAccountConfig) -> some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    Text("\(account.email) · \(account.imapHost)")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if testingAccountID == account.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        AppButton("测试", style: .secondary, size: .small) {
                            Task { await testConnection(account) }
                        }
                    }
                    AppButton("编辑", style: .secondary, size: .small) {
                        beginEditing(account)
                    }
                    AppButton("删除", style: .destructive, size: .small) {
                        delete(account)
                    }
                }
            }
        }
    }

    // MARK: - 添加入口

    private var addCard: some View {
        AppCard {
            AppSettingsSection(spacing: 12) {
                AppButton("添加账户", style: .primary, fillsWidth: true) {
                    beginAdding()
                }
            }
        }
    }

    // MARK: - 表单

    @ViewBuilder
    private var formCard: some View {
        if let draft = editingDraft {
            MailAccountFormView(
                initialDraft: draft,
                accountID: editingAccountID,
                sessionManager: sessionManager,
                onSave: { save($0) },
                onCancel: {
                    editingDraft = nil
                    editingAccountID = nil
                }
            )
        }
    }

    // MARK: - 操作

    private func reloadAccounts() {
        accounts = MailAccountStore.loadAccounts()
    }

    private func beginAdding() {
        editingAccountID = nil
        editingDraft = MailAccountDraft()
    }

    private func beginEditing(_ account: MailAccountConfig) {
        editingAccountID = account.id
        editingDraft = MailAccountDraft(
            config: account,
            password: MailAccountStore.password(for: account.id)
        )
    }

    private func save(_ draft: MailAccountDraft) {
        let id = editingAccountID ?? UUID()
        let config = draft.toConfig(id: id)
        MailAccountStore.upsertAccount(config)
        MailAccountStore.setPassword(draft.password, for: id)
        // 若编辑了已连接账户的凭据/主机，断开以强制下次重建会话。
        Task {
            await sessionManager.disconnect(accountID: id)
        }
        editingDraft = nil
        editingAccountID = nil
        reloadAccounts()
    }

    private func delete(_ account: MailAccountConfig) {
        MailAccountStore.deleteAccount(id: account.id)
        Task {
            await sessionManager.disconnect(accountID: account.id)
        }
        reloadAccounts()
    }

    private func testConnection(_ account: MailAccountConfig) async {
        testingAccountID = account.id
        errorMessage = nil
        defer { testingAccountID = nil }
        guard let password = MailAccountStore.password(for: account.id) else {
            errorMessage = "未找到该账户的密码，请先编辑并保存密码。"
            return
        }
        do {
            try await sessionManager.testConnection(account: account, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
