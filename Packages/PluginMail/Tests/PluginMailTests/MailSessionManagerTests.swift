import XCTest
import KitMail
@testable import PluginMail

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
