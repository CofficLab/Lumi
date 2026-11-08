import XCTest
import KitMail
@testable import PluginMail

@MainActor
final class MailWorkspaceViewModelTests: XCTestCase {
    /// 每个用例一套独立的临时目录 + 内存 Keychain：不读写真实用户凭据。
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!
    private var cache: MailCacheService!
    private var cacheDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-mail-workspace-\(UUID().uuidString)", isDirectory: true)
        cache = MailCacheService(databaseDirectory: cacheDirectory)
    }

    override func tearDownWithError() throws {
        cache = nil
        if let cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        cacheDirectory = nil
        fixture = nil
        store = nil
        try super.tearDownWithError()
    }

    private func makeAccount() -> MailAccountConfig {
        MailAccountConfig(
            id: UUID(),
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "zhangsan"
        )
    }

    private func makeCacheSummary(accountID: UUID, uid: UInt64, subject: String) -> MailMessageSummary {
        MailMessageSummary(
            accountID: accountID,
            folder: "INBOX",
            uid: uid,
            subject: subject,
            from: MailAddress(displayName: "李四", email: "lisi@example.com"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testColdStartOfflineFallsBackToCachedInbox() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)
        try await cache.upsertMessages(
            [makeCacheSummary(accountID: account.id, uid: 7, subject: "Cached")],
            accountID: account.id,
            folder: "INBOX"
        )

        let manager = MailSessionManager(
            factory: MockMailSessionFactory(behavior: .init(failConnect: true)),
            accountStore: store
        )
        let vm = MailWorkspaceViewModel(
            sessionManager: manager,
            cache: cache,
            accountStore: store,
            dataDirectory: cacheDirectory
        )

        await vm.load()

        XCTAssertTrue(vm.isOffline, "会话创建失败应标记离线")
        XCTAssertEqual(vm.folders.map(\.path), ["INBOX"], "离线时应保留 INBOX 入口")
        XCTAssertEqual(vm.messages.map(\.uid), [7], "应展示本地缓存摘要")
        XCTAssertEqual(vm.messages.first?.subject, "Cached")
        XCTAssertNotNil(vm.errorMessage)
    }

    /// 旧邮件的正文晚到，不能覆盖用户后来点开的邮件。
    func testStaleBodyDoesNotOverrideNewerSelection() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)

        let summaries = [
            makeCacheSummary(accountID: account.id, uid: 1, subject: "First"),
            makeCacheSummary(accountID: account.id, uid: 2, subject: "Second"),
        ]
        try await cache.upsertMessages(summaries, accountID: account.id, folder: "INBOX")

        let session = MockMailSession(messages: summaries)
        let manager = MailSessionManager(
            factory: MockMailSessionFactory(messages: summaries, session: session),
            accountStore: store
        )
        let vm = MailWorkspaceViewModel(
            sessionManager: manager,
            cache: cache,
            accountStore: store,
            dataDirectory: cacheDirectory,
            sync: MailSyncService(session: session, cache: cache)
        )
        await vm.load()
        await session.setBodyDelay(.milliseconds(300), forUID: 1)

        let first = try XCTUnwrap(vm.messages.first { $0.uid == 1 })
        let second = try XCTUnwrap(vm.messages.first { $0.uid == 2 })

        let stale = Task { await vm.selectMessage(first) }
        try await Task.sleep(for: .milliseconds(50))
        await vm.selectMessage(second)
        await stale.value

        XCTAssertEqual(vm.selectedMessage?.uid, 2)
        XCTAssertEqual(vm.selectedDetail?.summary.uid, 2, "旧邮件正文不能覆盖新选中的邮件")
    }

    /// 旧文件夹的同步晚到，不能覆盖新文件夹的列表，也不能提前关掉新同步的转圈。
    func testStaleFolderSyncKeepsNewerFolderAndSpinner() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)

        let inbox = makeCacheSummary(accountID: account.id, uid: 7, subject: "Inbox")
        var archived = makeCacheSummary(accountID: account.id, uid: 9, subject: "Archived")
        archived.folder = "Archive"
        try await cache.upsertMessages([inbox], accountID: account.id, folder: "INBOX")
        try await cache.upsertMessages([archived], accountID: account.id, folder: "Archive")

        let session = MockMailSession(messages: [inbox, archived])
        let manager = MailSessionManager(
            factory: MockMailSessionFactory(messages: [inbox, archived], session: session),
            accountStore: store
        )
        let vm = MailWorkspaceViewModel(
            sessionManager: manager,
            cache: cache,
            accountStore: store,
            dataDirectory: cacheDirectory,
            sync: MailSyncService(session: session, cache: cache)
        )
        await vm.load()
        XCTAssertEqual(vm.messages.map(\.uid), [7])

        await session.setFolderFetchDelay(.milliseconds(300), forFolder: "INBOX")
        await session.setFolderFetchDelay(.milliseconds(900), forFolder: "Archive")

        let stale = Task { await vm.refresh() }
        try await Task.sleep(for: .milliseconds(50))
        let fresh = Task {
            await vm.selectFolder(MailFolder(path: "Archive", kind: .archive, delimiter: "/"))
        }

        // 旧同步（300ms）已结束，新同步（900ms）仍在进行。
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(vm.isSyncing, "旧同步结束不应关闭新同步的转圈")

        await stale.value
        await fresh.value

        XCTAssertEqual(vm.selectedFolder, "Archive")
        XCTAssertEqual(vm.messages.map(\.uid), [9], "旧文件夹的同步结果不能覆盖当前文件夹列表")
        XCTAssertFalse(vm.isSyncing)
    }
}
