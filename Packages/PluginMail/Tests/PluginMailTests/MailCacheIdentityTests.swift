import XCTest
import KitMail
@testable import PluginMail

/// 编辑账户改变邮箱身份后必须清空旧缓存（issue #845）。
///
/// 设置页编辑保留原 UUID，若邮箱/用户名/主机变更后不清缓存，
/// 新邮箱会读到旧邮箱的邮件——跨账户数据泄露。
@MainActor
final class MailCacheIdentityTests: XCTestCase {
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!
    private var cache: MailCacheService!
    private var cacheDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-mail-identity-\(UUID().uuidString)", isDirectory: true)
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

    private func makeAccount(
        id: UUID = UUID(),
        email: String = "a@example.com",
        username: String = "a",
        imapHost: String = "imap.example.com",
        smtpHost: String = "smtp.example.com"
    ) -> MailAccountConfig {
        MailAccountConfig(
            id: id,
            displayName: "Test",
            email: email,
            imapHost: imapHost,
            smtpHost: smtpHost,
            username: username
        )
    }

    private func makeSummary(accountID: UUID, uid: UInt64) -> MailMessageSummary {
        MailMessageSummary(
            accountID: accountID,
            folder: "INBOX",
            uid: uid,
            subject: "Mail \(uid)",
            from: MailAddress(displayName: "Sender", email: "sender@example.com"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - 身份变更检测

    func testEmailChangeDetected() {
        let old = makeAccount(email: "a@example.com")
        let new = makeAccount(id: old.id, email: "b@example.com")
        XCTAssertTrue(Self.identityChanged(old: old, new: new))
    }

    func testUsernameChangeDetected() {
        let old = makeAccount(username: "a")
        let new = makeAccount(id: old.id, username: "b")
        XCTAssertTrue(Self.identityChanged(old: old, new: new))
    }

    func testImapHostChangeDetected() {
        let old = makeAccount(imapHost: "imap.a.com")
        let new = makeAccount(id: old.id, imapHost: "imap.b.com")
        XCTAssertTrue(Self.identityChanged(old: old, new: new))
    }

    func testSmtpHostChangeDetected() {
        let old = makeAccount(smtpHost: "smtp.a.com")
        let new = makeAccount(id: old.id, smtpHost: "smtp.b.com")
        XCTAssertTrue(Self.identityChanged(old: old, new: new))
    }

    func testDisplayNameChangeIsNotIdentityChange() {
        let old = makeAccount()
        var new = old
        new.displayName = "Different Name"
        XCTAssertFalse(Self.identityChanged(old: old, new: new))
    }

    func testPasswordChangeIsNotIdentityChange() {
        let old = makeAccount()
        let new = makeAccount(id: old.id)
        XCTAssertFalse(Self.identityChanged(old: old, new: new))
    }

    // MARK: - 缓存清空

    func testIdentityChangePurgesCache() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        try await cache.upsertMessages(
            [makeSummary(accountID: account.id, uid: 1),
             makeSummary(accountID: account.id, uid: 2)],
            accountID: account.id,
            folder: "INBOX"
        )
        let before = try await cache.messages(accountID: account.id, folder: "INBOX")
        XCTAssertEqual(before.count, 2)

        let edited = makeAccount(id: account.id, email: "b@other.com", imapHost: "imap.other.com")
        store.upsertAccount(edited)
        try await cache.purge(accountID: account.id)

        let after = try await cache.messages(accountID: account.id, folder: "INBOX")
        XCTAssertTrue(after.isEmpty, "身份变更后旧缓存必须被清空")
    }

    func testDeletePurgesCache() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        try await cache.upsertMessages(
            [makeSummary(accountID: account.id, uid: 1)],
            accountID: account.id,
            folder: "INBOX"
        )

        store.deleteAccount(id: account.id)
        try await cache.purge(accountID: account.id)

        let after = try await cache.messages(accountID: account.id, folder: "INBOX")
        XCTAssertTrue(after.isEmpty, "删除账户后缓存必须被清空")
    }

    func testUnchangedIdentityKeepsCache() async throws {
        let account = makeAccount()
        store.upsertAccount(account)
        try await cache.upsertMessages(
            [makeSummary(accountID: account.id, uid: 1)],
            accountID: account.id,
            folder: "INBOX"
        )

        var edited = account
        edited.displayName = "New Name"
        store.upsertAccount(edited)
        // 身份未变，不应 purge。

        let after = try await cache.messages(accountID: account.id, folder: "INBOX")
        XCTAssertEqual(after.count, 1, "仅改显示名不应清空缓存")
    }

    // MARK: - Helper

    /// 与 MailSettingsView.save 中的身份比较逻辑一致。
    private static func identityChanged(old: MailAccountConfig, new: MailAccountConfig) -> Bool {
        old.email != new.email
            || old.username != new.username
            || old.imapHost != new.imapHost
            || old.smtpHost != new.smtpHost
    }
}