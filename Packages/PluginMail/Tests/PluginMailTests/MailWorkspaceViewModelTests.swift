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
}
