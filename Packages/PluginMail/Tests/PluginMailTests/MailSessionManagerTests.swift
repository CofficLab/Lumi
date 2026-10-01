import XCTest
import KitMail
@testable import PluginMail

/// 内存会话替身（工厂注入用，不联网）。
final class MockMailSessionFactory: MailSessionFactory, @unchecked Sendable {
    struct Behavior {
        var failConnect = false
        var failMessages = false
        var failFolders = false
        var failSearch = false
    }

    private let behavior: Behavior
    private let messages: [MailMessageSummary]
    nonisolated(unsafe) private(set) var createdCount = 0

    init(
        behavior: Behavior = Behavior(),
        messages: [MailMessageSummary] = []
    ) {
        self.behavior = behavior
        self.messages = messages
    }

    func makeSession(
        account: MailAccountConfig,
        password: String
    ) async throws -> any MailSessionServing {
        createdCount += 1
        return MockMailSession(behavior: behavior, messages: messages)
    }
}

private actor MockMailSession: MailSessionServing {
    private let behavior: MockMailSessionFactory.Behavior
    private let messages: [MailMessageSummary]
    private(set) var connected = false

    init(behavior: MockMailSessionFactory.Behavior, messages: [MailMessageSummary]) {
        self.behavior = behavior
        self.messages = messages
    }

    func connect() async throws {
        if behavior.failConnect {
            throw MailError.authFailed
        }
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func listFolders() async throws -> [MailFolder] {
        if behavior.failFolders { throw MailError.network }
        return [
            MailFolder(path: "INBOX", kind: .inbox, delimiter: "/"),
            MailFolder(path: "[Gmail]/Sent Mail", kind: .sent, delimiter: "/"),
        ]
    }

    func fetchMessages(folder: String, sinceUID: UInt64?, limit: Int) async throws -> [MailMessageSummary] {
        if behavior.failMessages { throw MailError.protocolError("mock fetch failure") }
        return messages
    }

    func fetchBody(uid: UInt64, folder: String) async throws -> MailMessageDetail {
        MailMessageDetail(
            summary: messages.first { $0.uid == uid } ?? MailMessageSummary(
                accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                folder: folder,
                uid: uid,
                subject: "Subject",
                from: MailAddress(displayName: nil, email: "a@b.com"),
                date: Date(),
                isRead: false,
                isFlagged: false,
                hasAttachment: false
            ),
            htmlBody: "<p>Hello</p>",
            plainTextBody: "Hello",
            attachments: []
        )
    }

    func setFlags(uid: UInt64, folder: String, isRead: Bool?, isFlagged: Bool?) async throws {}

    func search(query: String, folder: String) async throws -> [UInt64] {
        if behavior.failSearch { throw MailError.network }
        return messages.map(\.uid)
    }

    func sendMessage(mime: Data) async throws {}

    func appendDraft(mime: Data, folder: String) async throws {}
}

final class MailSessionManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MailAccountStore.reset()
    }

    override func tearDown() {
        MailAccountStore.reset()
        super.tearDown()
    }

    private func makeAccount() -> MailAccountConfig {
        MailAccountConfig(
            id: UUID(),
            displayName: "Test",
            email: "test@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "test"
        )
    }

    func testSessionCachesByAccount() async throws {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory)
        let account = makeAccount()
        MailAccountStore.setPassword("p", for: account.id)

        let first = try await manager.session(for: account)
        let second = try await manager.session(for: account)
        // 同一账户只建一次会话（懒连接缓存）
        XCTAssertTrue(factory.createdCount == 1, "session should be created once")
        let _ = (first, second)
    }

    func testSessionThrowsAuthFailedWhenPasswordMissing() async {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory)
        let account = makeAccount()
        // 未存密码 → authFailed，且不创建会话
        do {
            _ = try await manager.session(for: account)
            XCTFail("expected authFailed")
        } catch let error as MailError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        XCTAssertEqual(factory.createdCount, 0)
    }

    func testSessionThrowsAuthFailedOnBadCredentials() async {
        let factory = MockMailSessionFactory(behavior: MockMailSessionFactory.Behavior(failConnect: true))
        let manager = MailSessionManager(factory: factory)
        let account = makeAccount()
        MailAccountStore.setPassword("wrong", for: account.id)

        do {
            _ = try await manager.session(for: account)
            XCTFail("expected authFailed")
        } catch let error as MailError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        // 连接失败不缓存会话
        XCTAssertEqual(factory.createdCount, 1)
        let count = await manager.activeCount
        XCTAssertEqual(count, 0)
    }

    func testDisconnectAndDisconnectAll() async throws {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory)
        let account = makeAccount()
        MailAccountStore.setPassword("p", for: account.id)

        _ = try await manager.session(for: account)
        var count = await manager.activeCount
        XCTAssertEqual(count, 1)

        await manager.disconnect(accountID: account.id)
        count = await manager.activeCount
        XCTAssertEqual(count, 0)

        _ = try await manager.session(for: account)
        await manager.disconnectAll()
        count = await manager.activeCount
        XCTAssertEqual(count, 0)
    }

    func testTestConnectionDoesNotCache() async throws {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory)
        let account = makeAccount()
        try await manager.testConnection(account: account, password: "p")
        let count = await manager.activeCount
        XCTAssertEqual(count, 0, "连接测试不缓存会话")
    }
}

final class MailPluginLocalStoreTests: XCTestCase {
    func testDefaults() {
        let store = MailPluginLocalStore(suiteName: "com.coffic.lumi.plugin.mail.test")
        store.reset()
        XCTAssertTrue(store.unreadBadgeEnabled)
        XCTAssertFalse(store.confirmBeforeLoadingHTML)

        store.unreadBadgeEnabled = false
        store.confirmBeforeLoadingHTML = true
        XCTAssertFalse(store.unreadBadgeEnabled)
        XCTAssertTrue(store.confirmBeforeLoadingHTML)
        store.reset()
    }
}
