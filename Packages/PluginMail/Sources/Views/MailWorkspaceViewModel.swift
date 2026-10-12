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

    // 撰写
    @Published var isComposerPresented = false
    @Published var composeMode: MailComposeMode = .new
    @Published private(set) var composeDetail: MailMessageDetail?

    init(
        sessionManager: MailSessionManager,
        cache: MailCacheService,
        sync: MailSyncService? = nil,
        composer: MailComposerService? = nil
    ) {
        self.sessionManager = sessionManager
        self.cache = cache
        self.sync = sync
        self.composer = composer ?? MailComposerService(sessionManager: sessionManager)
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
                mode: composeMode,
                originalDetail: composeDetail
            )
        }
        return MailComposeViewModel(
            composer: composer,
            sessionManager: sessionManager,
            account: account,
            mode: composeMode,
            originalDetail: composeDetail
        )
    }

    // MARK: - 生命周期

    func load() async {
        accounts = MailAccountStore.loadAccounts()
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
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        do {
            let session = try await sessionManager.session(for: account)
            let remoteFolders = try await session.listFolders()
            // 本地优先：INBOX 缺省兜底
            let list = remoteFolders.isEmpty
                ? [MailFolder(path: "INBOX", kind: .inbox, delimiter: "/")]
                : remoteFolders
            folders = list.sorted { $0.kind.sortOrder < $1.kind.sortOrder }
            await syncAndLoad(folder: "INBOX", fullSync: true)
        } catch {
            handleError(error, context: "加载文件夹")
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
        await syncAndLoad(folder: selectedFolder, fullSync: true)
    }

    private func syncAndLoad(folder: String, fullSync: Bool = false) async {
        guard let accountID = selectedAccountID else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            if let sync {
                _ = try await sync.syncFolder(folder, accountID: accountID, fullSync: fullSync)
            } else if let account = accounts.first(where: { $0.id == accountID }) {
                let session = try await sessionManager.session(for: account)
                let summaries = try await session.fetchMessages(folder: folder, sinceUID: nil, limit: pageSize)
                try await cache.upsertMessages(summaries, accountID: accountID, folder: folder)
            }
            isOffline = false
            await loadMessages(folder: folder, reset: true)
            await refreshUnreadBadges()
        } catch {
            isOffline = true
            handleError(error, context: "同步 \(folder)")
            // 离线降级：仍展示本地缓存
            await loadMessages(folder: folder, reset: true)
        }
    }

    private func loadMessages(folder: String, reset: Bool) async {
        guard let accountID = selectedAccountID else { return }
        do {
            let all = try await cache.messages(accountID: accountID, folder: folder)
            loadedCount = reset ? pageSize : loadedCount
            messages = Array(all.prefix(loadedCount))
        } catch {
            messages = []
        }
    }

    /// 分页加载（列表滚动到底部时调用）。
    func loadMore() async {
        guard let accountID = selectedAccountID, !messages.isEmpty else { return }
        loadedCount += pageSize
        let all = (try? await cache.messages(accountID: accountID, folder: selectedFolder)) ?? []
        messages = Array(all.prefix(loadedCount))
    }

    // MARK: - 阅读

    func selectMessage(_ message: MailCacheItem.Summary) async {
        selectedMessage = message
        selectedDetail = nil
        guard let accountID = selectedAccountID else { return }
        do {
            if let sync {
                let session = try await currentSession()
                let detail = try await session.fetchBody(uid: message.uid, folder: selectedFolder)
                try await cache.upsertDetail(detail, accountID: accountID, folder: selectedFolder)
                selectedDetail = detail
                // 阅读即已读（写缓存 + 服务端）
                try await cache.setFlags(
                    accountID: accountID, folder: selectedFolder, uid: message.uid,
                    isRead: true, isFlagged: nil
                )
                await refreshUnreadBadges()
            }
        } catch {
            handleError(error, context: "读取邮件")
        }
    }

    private func currentSession() async throws -> any MailSessionServing {
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else {
            throw MailError.offline
        }
        return try await sessionManager.session(for: account)
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
