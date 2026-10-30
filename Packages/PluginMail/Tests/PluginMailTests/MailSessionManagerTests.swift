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
        let manager = MailSessionManager(factory: factory, accountStore: store)
        let account = makeAccount()
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
