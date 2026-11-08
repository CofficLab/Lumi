import Foundation
import SwiftUI
import KitMail

/// 邮件工作区 ViewModel：账户/文件夹/列表/阅读状态编排。
///
/// - 数据流：账户 → 文件夹 → 增量同步写 `MailCacheService` → 列表读缓存；
/// - 阅读：点选后 `fetchBody` 取正文（写入缓存），HTML/纯文本降级在 Reader 渲染；
/// - 搜索：本地缓存 LIKE（离线可用），后续 Phase 5 接 Agent 工具。
@MainActor
final class MailWorkspaceViewModel: ObservableObject {
    // 依赖
    private let sessionManager: MailSessionManager
    private let cache: MailCacheService
    private let sync: MailSyncService?
    private let accountStore: MailAccountStore
    /// 插件数据目录（由 `MailPlugin` 经 `StorageProviding` 解析后注入）。
    private let dataDirectory: URL
    let composer: MailComposerService

    // 状态
    @Published private(set) var accounts: [MailAccountConfig] = []
    @Published private(set) var folders: [MailFolder] = []
    @Published private(set) var messages: [MailCacheItem.Summary] = []
    @Published private(set) var selectedMessage: MailCacheItem.Summary?
    @Published private(set) var selectedDetail: MailMessageDetail?
    @Published private(set) var isSyncing = false
    @Published private(set) var isOffline = false
    @Published var errorMessage: String?

    /// 当前选中账户/文件夹。
    private(set) var selectedAccountID: UUID?
    private(set) var selectedFolder: String = "INBOX"

    // 分页
    private let pageSize = 50
    private var loadedCount = 0

    /// 正在同步的任务标识；只有仍在生效的那次同步才能关闭转圈。
    private var activeSyncToken: UUID?

    /// 列表/详情异步结果的绑定身份：账户 + 文件夹。
    /// 写回共享状态前必须与当前选择比对，避免旧任务覆盖新上下文。
    private struct MailViewContext: Equatable {
        let accountID: UUID
        let folder: String
    }

    private var currentContext: MailViewContext? {
        guard let selectedAccountID else { return nil }
        return MailViewContext(accountID: selectedAccountID, folder: selectedFolder)
    }

    // 撰写
    @Published var isComposerPresented = false
    @Published var composeMode: MailComposeMode = .new
    @Published private(set) var composeDetail: MailMessageDetail?

    init(
        sessionManager: MailSessionManager,
        cache: MailCacheService,
        accountStore: MailAccountStore,
        dataDirectory: URL,
        sync: MailSyncService? = nil,
        composer: MailComposerService? = nil
    ) {
        self.sessionManager = sessionManager
        self.cache = cache
        self.accountStore = accountStore
        self.dataDirectory = dataDirectory
        self.sync = sync
        self.composer = composer ?? MailComposerService(
            sessionManager: sessionManager,
            accountStore: accountStore
        )
    }

    // MARK: - 撰写入口

    func openComposer(mode: MailComposeMode, detail: MailMessageDetail? = nil) {
        composeMode = mode
        composeDetail = detail
        isComposerPresented = true
    }

    func dismissComposer() {
        isComposerPresented = false
        composeDetail = nil
    }

    func makeComposeViewModel() -> MailComposeViewModel {
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else {
            // 无账户兜底：新建仍可用（发送时会因 authFailed 提示）
            return MailComposeViewModel(
                composer: composer,
                sessionManager: sessionManager,
                account: MailAccountConfig(
                    id: UUID(),
                    displayName: "",
                    email: "",
                    imapHost: "",
                    smtpHost: "",
                    username: ""
                ),
                dataDirectory: dataDirectory,
                mode: composeMode,
                originalDetail: composeDetail
            )
        }
        return MailComposeViewModel(
            composer: composer,
            sessionManager: sessionManager,
            account: account,
            dataDirectory: dataDirectory,
            mode: composeMode,
            originalDetail: composeDetail
        )
    }

    // MARK: - 生命周期

    func load() async {
        accounts = accountStore.loadAccounts()
        if let first = accounts.first {
            await selectAccount(id: first.id)
        }
        await refreshUnreadBadges()
    }

    /// 选择账户：拉文件夹列表 + 首个文件夹（INBOX）同步。
    func selectAccount(id: UUID) async {
        selectedAccountID = id
        selectedFolder = "INBOX"
        folders = []
        messages = []
        selectedMessage = nil
        selectedDetail = nil
        guard let account = accounts.first(where: { $0.id == id }),
              let context = currentContext else { return }
        do {
            let session = try await sessionManager.session(for: account)
            let remoteFolders = try await session.listFolders()
            guard currentContext == context else { return }
            // 本地优先：INBOX 缺省兜底
            let list = remoteFolders.isEmpty
                ? [MailFolder(path: "INBOX", kind: .inbox, delimiter: "/")]
                : remoteFolders
            folders = list.sorted { $0.kind.sortOrder < $1.kind.sortOrder }
            await syncAndLoad(folder: "INBOX", fullSync: true)
        } catch {
            guard currentContext == context else { return }
            // 冷启动离线：会话或文件夹列表失败时仍保留 INBOX 入口，
            // 并用本地缓存渲染列表，而不是留下空白工作区。
            isOffline = true
            folders = [MailFolder(path: "INBOX", kind: .inbox, delimiter: "/")]
            handleError(error, context: "加载文件夹")
            await loadMessages(folder: "INBOX", reset: true)
        }
    }

    // MARK: - 文件夹与列表

    /// 切换文件夹并（增量）同步。
    func selectFolder(_ folder: MailFolder) async {
        selectedFolder = folder.path
        messages = []
        selectedMessage = nil
        selectedDetail = nil
        await syncAndLoad(folder: folder.path)
    }

    func refresh() async {
        // 离线期间文件夹列表只保留了 INBOX 兜底，恢复后需重新拉取远程文件夹。
        if isOffline, let accountID = selectedAccountID {
            await selectAccount(id: accountID)
            return
        }
        await syncAndLoad(folder: selectedFolder, fullSync: true)
    }

    private func syncAndLoad(folder: String, fullSync: Bool = false) async {
        guard let context = currentContext else { return }
        let accountID = context.accountID
        let token = UUID()
        activeSyncToken = token
        isSyncing = true
        errorMessage = nil
        defer {
            // 旧同步结束不能关掉新同步的转圈。
            if activeSyncToken == token {
                activeSyncToken = nil
                isSyncing = false
            }
        }
        do {
            if let sync {
                _ = try await sync.syncFolder(folder, accountID: accountID, fullSync: fullSync)
            } else if let account = accounts.first(where: { $0.id == accountID }) {
                let session = try await sessionManager.session(for: account)
                let summaries = try await session.fetchMessages(folder: folder, sinceUID: nil, limit: pageSize)
                try await cache.upsertMessages(summaries, accountID: accountID, folder: folder)
            }
            guard currentContext == context else { return }
            isOffline = false
            await loadMessages(folder: folder, reset: true)
            await refreshUnreadBadges()
        } catch {
            guard currentContext == context else { return }
            isOffline = true
            handleError(error, context: "同步 \(folder)")
            // 离线降级：仍展示本地缓存
            await loadMessages(folder: folder, reset: true)
        }
    }

    private func loadMessages(folder: String, reset: Bool) async {
        guard let accountID = selectedAccountID else { return }
        let context = MailViewContext(accountID: accountID, folder: folder)
        do {
            let all = try await cache.messages(accountID: accountID, folder: folder)
            guard currentContext == context else { return }
            loadedCount = reset ? pageSize : loadedCount
            messages = Array(all.prefix(loadedCount))
        } catch {
            guard currentContext == context else { return }
            messages = []
        }
    }

    /// 分页加载（列表滚动到底部时调用）。
    func loadMore() async {
        guard let context = currentContext, !messages.isEmpty else { return }
        let targetCount = loadedCount + pageSize
        let all = (try? await cache.messages(accountID: context.accountID, folder: context.folder)) ?? []
        guard currentContext == context else { return }
        loadedCount = targetCount
        messages = Array(all.prefix(loadedCount))
    }

    // MARK: - 阅读

    func selectMessage(_ message: MailCacheItem.Summary) async {
        selectedMessage = message
        selectedDetail = nil
        guard let context = currentContext,
              let account = accounts.first(where: { $0.id == context.accountID }) else { return }
        do {
            if let sync {
                let session = try await sessionManager.session(for: account)
                let detail = try await session.fetchBody(uid: message.uid, folder: context.folder)
                try await cache.upsertDetail(detail, accountID: context.accountID, folder: context.folder)
                // 旧邮件的正文晚到，不能盖掉用户后来点开的邮件。
                guard currentContext == context, selectedMessage?.uid == message.uid else { return }
                selectedDetail = detail
                // 阅读即已读（写缓存 + 服务端）
                try await cache.setFlags(
                    accountID: context.accountID, folder: context.folder, uid: message.uid,
                    isRead: true, isFlagged: nil
                )
                await refreshUnreadBadges()
            }
        } catch {
            guard currentContext == context, selectedMessage?.uid == message.uid else { return }
            handleError(error, context: "读取邮件")
        }
    }

    // MARK: - 未读徽标

    private func refreshUnreadBadges() async {
        // 文件夹未读数由各 Sidebar 行按需查询；此处预留聚合钩子。
    }

    /// 单文件夹未读（文件夹树徽标）。
    func unreadCount(folder: String) async -> Int {
        guard let accountID = selectedAccountID else { return 0 }
        return (try? await cache.unreadCount(accountID: accountID, folder: folder)) ?? 0
    }

    // MARK: - 错误

    private func handleError(_ error: Error, context: String) {
        if let mailError = error as? MailError {
            errorMessage = "\(context)失败：\(mailError.localizedDescription)"
        } else {
            errorMessage = "\(context)失败：\(error.localizedDescription)"
        }
    }
}

extension MailFolderKind {
    /// 文件夹树排序：收件箱最前，其余按枚举顺序。
    var sortOrder: Int {
        switch self {
        case .inbox: return 0
        case .all: return 1
        case .sent: return 2
        case .drafts: return 3
        case .junk: return 4
        case .trash: return 5
        case .archive: return 6
        case .other: return 7
        }
    }
}
