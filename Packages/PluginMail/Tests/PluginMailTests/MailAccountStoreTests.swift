import XCTest
import KitMail
@testable import PluginMail

final class MailAccountStoreTests: XCTestCase {
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!
    private var directory: URL { fixture.directoryForAssertions }

    /// 每个用例一个独立临时目录 + 一个内存 Keychain：
    /// 既保证用例之间互不污染，也保证不读写真实用户数据。
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

    private func makeAccount(id: UUID = UUID()) -> MailAccountConfig {
        MailAccountConfig(
            id: id,
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            username: "zhangsan",
            loginType: .password,
            useTLS: true
        )
    }

    // MARK: - 账户配置

    func testUpsertAndLoad() {
        store.upsertAccount(makeAccount())
        XCTAssertEqual(store.loadAccounts().count, 1)
        XCTAssertEqual(store.loadAccounts().first?.email, "zhangsan@example.com")
    }

    func testUpsertUpdatesExistingByID() {
        let id = UUID()
        var account = makeAccount(id: id)
        store.upsertAccount(account)
        account.displayName = "李四"
        store.upsertAccount(account)
        let accounts = store.loadAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.displayName, "李四")
    }

    func testDeleteRemovesAccountAndPassword() {
        let id = UUID()
        store.upsertAccount(makeAccount(id: id))
        store.setPassword("secret", for: id)
        XCTAssertNotNil(store.password(for: id))

        store.deleteAccount(id: id)
        XCTAssertTrue(store.loadAccounts().isEmpty)
        XCTAssertNil(store.password(for: id), "删除账户必须同时清除 Keychain 密码")
    }

    func testPasswordRoundTrip() {
        let id = UUID()
        store.setPassword("app-password-123", for: id)
        XCTAssertEqual(store.password(for: id), "app-password-123")

        store.setPassword("changed", for: id)
        XCTAssertEqual(store.password(for: id), "changed")

        store.setPassword(nil, for: id)
        XCTAssertNil(store.password(for: id))
    }

    func testEmptyStringPasswordIsTreatedAsDelete() {
        let id = UUID()
        store.setPassword("secret", for: id)
        store.setPassword("", for: id)
        XCTAssertNil(store.password(for: id))
    }

    /// 配置落盘在插件数据目录内，且**不含密码**。
    ///
    /// 这是插件存储规范的硬要求：配置归 `accounts.plist`，密码只进 Keychain。
    func testStoredConfigLandsInPluginDirectoryWithoutPassword() throws {
        let id = UUID()
        store.upsertAccount(makeAccount(id: id))
        store.setPassword("top-secret-password", for: id)

        let plistURL = directory.appendingPathComponent("accounts.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path))
        XCTAssertEqual(plistURL.deletingLastPathComponent().standardizedFileURL.path,
                       directory.standardizedFileURL.path)

        let raw = try Data(contentsOf: plistURL)
        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertFalse(text.contains("top-secret-password"), "配置 plist 泄露密码")
    }

    func testAccountsSurviveANewStoreInstance() throws {
        let account = makeAccount()
        store.upsertAccount(account)
        store.setPassword("persisted", for: account.id)

        // 模拟 App 重启：同目录 + 全新内存 Keychain。
        // 配置必须能从磁盘读回；密码因 Keychain 是空的而读不到，
        // 正好锁住「配置归磁盘、密码归 Keychain」这条边界。
        let reopened = fixture.reopenedStore()
        let loaded = reopened.loadAccounts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.email, "zhangsan@example.com")
        XCTAssertNil(reopened.password(for: account.id), "重启后密码应来自系统 Keychain，此处为空")
    }

    /// 损坏的 plist 必须被隔离成 `.corrupt` 并返回空列表，而不是抛出或死循环报错。
    func testCorruptConfigIsQuarantinedAndReadsAsEmpty() throws {
        let plistURL = directory.appendingPathComponent("accounts.plist")
        try Data("not a plist at all".utf8).write(to: plistURL)

        XCTAssertEqual(store.loadAccounts().count, 0)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("accounts.corrupt.plist").path
            ),
            "损坏配置应被隔离为 accounts.corrupt.plist"
        )
    }

    func testLoadEmptyWhenNoConfigFileExists() {
        // 目录是全新的，不存在 accounts.plist。
        XCTAssertTrue(store.loadAccounts().isEmpty)
    }
}

// MARK: - 旧版 UserDefaults 迁移

/// 覆盖「老用户升级后不丢账户」这条数据安全底线。
final class MailAccountStoreMigrationTests: XCTestCase {
    private func makeAccount(
        id: UUID = UUID(),
        email: String = "legacy@example.com"
    ) -> MailAccountConfig {
        MailAccountConfig(
            id: id,
            displayName: "Legacy",
            email: email,
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "legacy"
        )
    }

    /// 老用户已配的账户必须出现在新的 accounts.plist 里。
    func testLegacyAccountsAreImportedIntoPlist() throws {
        let account = makeAccount()
        let fixture = try MailAccountStoreFixture(legacyAccounts: [account])

        let loaded = fixture.store.loadAccounts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, account.id)
        XCTAssertEqual(loaded.first?.email, "legacy@example.com")
    }

    /// 迁移成功后旧 key 必须清掉，否则留下永久脏数据。
    func testLegacyKeyIsClearedAfterSuccessfulMigration() throws {
        let fixture = try MailAccountStoreFixture(legacyAccounts: [makeAccount()])
        XCTAssertNil(fixture.legacyDefaults.data(forKey: "MailPlugin.savedAccounts"))
    }

    /// 幂等：第二次启动不得重复导入或产生副作用。
    func testMigrationIsIdempotentAcrossRestarts() throws {
        let account = makeAccount()
        let fixture = try MailAccountStoreFixture(legacyAccounts: [account])

        // 模拟旧 key 被外部重新塞回（不应发生，但要保证不会重复导入）。
        fixture.legacyDefaults.set(
            try JSONEncoder().encode([account]),
            forKey: "MailPlugin.savedAccounts"
        )
        let reopened = fixture.reopenedStore(legacyDefaults: fixture.legacyDefaults)
        XCTAssertEqual(reopened.loadAccounts().count, 1)
    }

    /// 从未配过邮箱的用户：留空，不报错。
    func testNoLegacyDataLeavesStoreEmpty() throws {
        let fixture = try MailAccountStoreFixture()
        XCTAssertTrue(fixture.store.loadAccounts().isEmpty)
    }

    /// 旧数据损坏时**必须保留**它，且不写迁移标记——
    /// 这样用户修复偏好文件后下次启动还能重试，不会静默丢账户。
    func testCorruptLegacyDataIsPreservedAndNotMarkedMigrated() throws {
        let fixture = try MailAccountStoreFixture()
        fixture.legacyDefaults.set(Data("garbage".utf8), forKey: "MailPlugin.savedAccounts")

        let reopened = fixture.reopenedStore(legacyDefaults: fixture.legacyDefaults)
        XCTAssertTrue(reopened.loadAccounts().isEmpty)
        XCTAssertNotNil(
            fixture.legacyDefaults.data(forKey: "MailPlugin.savedAccounts"),
            "旧数据解析失败时必须保留，供下次启动重试"
        )

        // 未写迁移标记：再用同样的坏数据开一次，仍应尝试迁移。
        let again = fixture.reopenedStore(legacyDefaults: fixture.legacyDefaults)
        XCTAssertTrue(again.loadAccounts().isEmpty)
    }

    /// plist 已有账户时不覆盖用户的新数据。
    func testExistingAccountsAreNotOverwrittenByLegacyData() throws {
        let fixture = try MailAccountStoreFixture()
        let mine = makeAccount(email: "mine@example.com")
        fixture.store.upsertAccount(mine)

        fixture.legacyDefaults.set(
            try JSONEncoder().encode([makeAccount(email: "stale@example.com")]),
            forKey: "MailPlugin.savedAccounts"
        )
        let reopened = fixture.reopenedStore(legacyDefaults: fixture.legacyDefaults)

        let loaded = reopened.loadAccounts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.email, "mine@example.com", "已有账户不应被旧数据覆盖")
    }
}

// MARK: - 插件本地偏好

final class MailPluginLocalStoreTests: XCTestCase {
    private var fixture: MailLocalStoreFixture!
    private var store: MailPluginLocalStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailLocalStoreFixture()
        store = fixture.store
    }

    override func tearDownWithError() throws {
        fixture = nil
        store = nil
        try super.tearDownWithError()
    }

    func testDefaults() {
        XCTAssertTrue(store.unreadBadgeEnabled, "未读角标缺省开启")
        XCTAssertFalse(store.confirmBeforeLoadingHTML, "HTML 确认缺省关闭")
    }

    func testRoundTrip() {
        store.unreadBadgeEnabled = false
        store.confirmBeforeLoadingHTML = true
        XCTAssertFalse(store.unreadBadgeEnabled)
        XCTAssertTrue(store.confirmBeforeLoadingHTML)
    }

    /// 偏好必须落在插件数据目录内（不是 UserDefaults 域）。
    func testPreferencesLandInPluginDirectory() {
        store.confirmBeforeLoadingHTML = true
        let plist = fixture.directoryForAssertions.appendingPathComponent("preferences.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plist.path))
    }

    /// 新实例必须能读回偏好（App 重启后设置不丢）。
    func testPreferencesSurviveNewStoreInstance() {
        store.unreadBadgeEnabled = false
        let reopened = MailPluginLocalStore(directory: fixture.directoryForAssertions)
        XCTAssertFalse(reopened.unreadBadgeEnabled)
    }

    func testCorruptPreferencesAreQuarantined() throws {
        let plist = fixture.directoryForAssertions.appendingPathComponent("preferences.plist")
        try Data("not a plist".utf8).write(to: plist)

        // 读回缺省值，不抛错。
        XCTAssertTrue(store.unreadBadgeEnabled)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.directoryForAssertions
                    .appendingPathComponent("preferences.corrupt.plist").path
            )
        )
    }
}

final class MailProviderPresetTests: XCTestCase {
    func testPresetHostsAndPorts() {
        XCTAssertEqual(MailProviderPreset.gmail.imapHost, "imap.gmail.com")
        XCTAssertEqual(MailProviderPreset.gmail.smtpHost, "smtp.gmail.com")
        XCTAssertEqual(MailProviderPreset.gmail.smtpPort, 465)
        XCTAssertEqual(MailProviderPreset.icloud.smtpPort, 587)
        XCTAssertEqual(MailProviderPreset.outlook.imapHost, "outlook.office365.com")
        XCTAssertNil(MailProviderPreset.custom.imapHost)
    }

    func testInferFromIMAPHost() {
        XCTAssertEqual(MailProviderPreset.infer(imapHost: "imap.qq.com"), .qq)
        XCTAssertEqual(MailProviderPreset.infer(imapHost: "IMAP.GMAIL.COM"), .gmail)
        XCTAssertEqual(MailProviderPreset.infer(imapHost: "mail.company.com"), .custom)
    }
}

final class MailAccountDraftTests: XCTestCase {
    func testToConfigMapsTypes() {
        var draft = MailAccountDraft(provider: .qq)
        draft.displayName = "王五"
        draft.email = "wangwu@qq.com"
        draft.password = "authcode"
        draft.applyPresetDefaults()

        let config = draft.toConfig()
        XCTAssertEqual(config.imapHost, "imap.qq.com")
        XCTAssertEqual(config.imapPort, 993)
        XCTAssertEqual(config.smtpHost, "smtp.qq.com")
        XCTAssertEqual(config.smtpPort, 465)
        XCTAssertEqual(config.username, "wangwu@qq.com", "QQ 预设用户名默认等于邮箱")
        XCTAssertEqual(config.loginType, .password)
        XCTAssertTrue(config.useTLS)
    }

    func testApplyPresetKeepsCustomHosts() {
        var draft = MailAccountDraft(provider: .custom)
        draft.imapHost = "mail.mycompany.com"
        draft.smtpHost = "smtp.mycompany.com"
        draft.applyPresetDefaults()
        XCTAssertEqual(draft.imapHost, "mail.mycompany.com", "custom 预设保留用户填写")
        XCTAssertEqual(draft.smtpHost, "smtp.mycompany.com")
    }
}
