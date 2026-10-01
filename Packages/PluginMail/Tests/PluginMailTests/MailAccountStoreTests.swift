import XCTest
import KitMail
@testable import PluginMail

final class MailAccountStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MailAccountStore.reset()
    }

    override func tearDown() {
        MailAccountStore.reset()
        super.tearDown()
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

    func testUpsertAndLoad() {
        let account = makeAccount()
        MailAccountStore.upsertAccount(account)
        XCTAssertEqual(MailAccountStore.loadAccounts().count, 1)
        XCTAssertEqual(MailAccountStore.loadAccounts().first?.email, "zhangsan@example.com")
    }

    func testUpsertUpdatesExistingByID() {
        let id = UUID()
        var account = makeAccount(id: id)
        MailAccountStore.upsertAccount(account)
        account.displayName = "李四"
        MailAccountStore.upsertAccount(account)
        let accounts = MailAccountStore.loadAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.displayName, "李四")
    }

    func testDeleteRemovesAccountAndPassword() {
        let id = UUID()
        MailAccountStore.upsertAccount(makeAccount(id: id))
        MailAccountStore.setPassword("secret", for: id)
        XCTAssertNotNil(MailAccountStore.password(for: id))

        MailAccountStore.deleteAccount(id: id)
        XCTAssertTrue(MailAccountStore.loadAccounts().isEmpty)
        XCTAssertNil(MailAccountStore.password(for: id), "删除账户必须同时清除 Keychain 密码")
    }

    func testPasswordRoundTrip() {
        let id = UUID()
        MailAccountStore.setPassword("app-password-123", for: id)
        XCTAssertEqual(MailAccountStore.password(for: id), "app-password-123")

        MailAccountStore.setPassword("changed", for: id)
        XCTAssertEqual(MailAccountStore.password(for: id), "changed")

        MailAccountStore.setPassword(nil, for: id)
        XCTAssertNil(MailAccountStore.password(for: id))
    }

    func testStoredJSONDoesNotContainPassword() {
        let id = UUID()
        MailAccountStore.upsertAccount(makeAccount(id: id))
        MailAccountStore.setPassword("top-secret-password", for: id)

        // 从 UserDefaults 原始数据里读 JSON，密码绝不能出现
        let key = "MailPlugin.savedAccounts"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            XCTFail("saved accounts missing from UserDefaults")
            return
        }
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("top-secret-password"), "配置 JSON 泄露密码")
    }

    func testLoadEmptyWhenNothingSaved() {
        XCTAssertTrue(MailAccountStore.loadAccounts().isEmpty)
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
