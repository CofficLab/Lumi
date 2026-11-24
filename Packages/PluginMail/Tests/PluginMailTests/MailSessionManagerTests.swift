import XCTest
import KitMail
@testable import PluginMail

final class MailSessionManagerTests: XCTestCase {
    /// 每个用例一套独立的临时目录 + 内存 Keychain：不读写真实用户凭据。
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
    }

    override func tearDownWithError() throws {
        fixture = nil
        store = nil
        try super.tearDownWithError()
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
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)

        let first = try await manager.session(for: account)
        let second = try await manager.session(for: account)
        // 同一账户只建一次会话（懒连接缓存）
        XCTAssertTrue(factory.createdCount == 1, "session should be created once")
        let _ = (first, second)
    }

    func testSessionThrowsAuthFailedWhenPasswordMissing() async {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        // 账户在存储中但未存密码 → authFailed，且不创建会话
        store.upsertAccount(account)
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

    func testSessionThrowsNotFoundForUnknownAccount() async throws {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        // 账户不在存储中（已删除）：不建连，报 notFound（回归 #400）。
        do {
            _ = try await manager.session(for: account)
            XCTFail("expected notFound")
        } catch let error as MailError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        XCTAssertEqual(factory.createdCount, 0)
    }

    func testSessionConnectsWithCurrentStoreConfig() async throws {
        let factory = MockMailSessionFactory()
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let id = UUID()
        let stale = MailAccountConfig(
            id: id, displayName: "Test", email: "test@example.com",
            imapHost: "imap.old.example.com", smtpHost: "smtp.old.example.com", username: "old"
        )
        let current = MailAccountConfig(
            id: id, displayName: "Test", email: "test@example.com",
            imapHost: "imap.new.example.com", smtpHost: "smtp.new.example.com", username: "new"
        )
        store.upsertAccount(current)
        store.setPassword("p", for: id)

        // 调用方持保存编辑前的旧快照（设置页保存后工作区不会重载 accounts）。
        _ = try await manager.session(for: stale)

        // 修复前：用快照建连，一直连到旧主机（#400）。
        XCTAssertEqual(factory.lastAccount?.imapHost, "imap.new.example.com")
    }

    func testInFlightSessionInvalidatedByDisconnect() async throws {
        let behavior = MockMailSessionFactory.Behavior(connectDelay: .milliseconds(500))
        let factory = MockMailSessionFactory(behavior: behavior)
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)

        // 首连进行中（connect 挂起 500ms）保存新凭据：disconnect 递增代次。
        let pending = Task { try await manager.session(for: account) }
        var waited = 0
        while factory.createdCount == 0 && waited < 50 {
            try await Task.sleep(for: .milliseconds(10))
            waited += 1
        }
        XCTAssertTrue(factory.createdCount >= 1, "连接应已开始建立")
        await manager.disconnect(accountID: account.id)

        do {
            _ = try await pending.value
            XCTFail("迟到的旧凭据连接必须被作废")
        } catch let error as MailError {
            XCTAssertEqual(error, .connectionInvalidated)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        // 旧连接被关闭，且未写入缓存供后续复用（#400）。
        let session = try XCTUnwrap(factory.lastSession)
        let connected = await session.connected
        XCTAssertFalse(connected, "作废的迟到连接必须被关闭")
        let count = await manager.activeCount
        XCTAssertEqual(count, 0)
    }

    func testSessionThrowsAuthFailedOnBadCredentials() async {
        let factory = MockMailSessionFactory(behavior: MockMailSessionFactory.Behavior(failConnect: true))
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("wrong", for: account.id)

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
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("p", for: account.id)

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
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
        try await manager.testConnection(account: account, password: "p")
        let count = await manager.activeCount
        XCTAssertEqual(count, 0, "连接测试不缓存会话")
    }
}
