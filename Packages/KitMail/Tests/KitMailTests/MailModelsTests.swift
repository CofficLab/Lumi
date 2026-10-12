import XCTest
@testable import KitMail

final class MailModelsTests: XCTestCase {
    // MARK: - MailAddress

    func testAddressRoundTrip() throws {
        let address = MailAddress(displayName: "张三", email: "zhangsan@example.com")
        let data = try JSONEncoder().encode(address)
        let decoded = try JSONDecoder().decode(MailAddress.self, from: data)
        XCTAssertEqual(decoded, address)
    }

    func testAddressRFC5322() {
        XCTAssertEqual(
            MailAddress(displayName: "张三", email: "a@b.com").rfc5322,
            "\"张三\" <a@b.com>"
        )
        XCTAssertEqual(
            MailAddress(displayName: nil, email: "a@b.com").rfc5322,
            "a@b.com"
        )
        // 引号转义
        XCTAssertEqual(
            MailAddress(displayName: "He said \"hi\"", email: "a@b.com").rfc5322,
            "\"He said \\\"hi\\\"\" <a@b.com>"
        )
    }

    func testAddressHashable() {
        XCTAssertEqual(
            MailAddress(displayName: "A", email: "x@y.com"),
            MailAddress(displayName: "B", email: "x@y.com")
        )
    }

    // MARK: - MailAccountConfig

    func testAccountConfigRoundTrip() throws {
        let config = MailAccountConfig(
            displayName: "QQ 邮箱",
            email: "user@qq.com",
            imapHost: "imap.qq.com",
            smtpHost: "smtp.qq.com",
            username: "user@qq.com"
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MailAccountConfig.self, from: data)
        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.imapPort, 993)
        XCTAssertEqual(decoded.smtpPort, 465)
        XCTAssertEqual(decoded.loginType, .password)
    }

    func testAccountConfigDefaultTLS() {
        let config = MailAccountConfig(
            displayName: "T",
            email: "t@t.com",
            imapHost: "imap.t.com",
            smtpHost: "smtp.t.com",
            username: "t"
        )
        XCTAssertTrue(config.useTLS)
    }

    // MARK: - MailFolder

    func testFolderKindInference() {
        XCTAssertEqual(MailFolder.inferKind(from: "INBOX"), .inbox)
        XCTAssertEqual(MailFolder.inferKind(from: "Sent Mail"), .sent)
        XCTAssertEqual(MailFolder.inferKind(from: "已发送"), .sent)
        XCTAssertEqual(MailFolder.inferKind(from: "Drafts"), .drafts)
        XCTAssertEqual(MailFolder.inferKind(from: "Trash"), .trash)
        XCTAssertEqual(MailFolder.inferKind(from: "Spam"), .junk)
        XCTAssertEqual(MailFolder.inferKind(from: "Archive"), .archive)
        XCTAssertEqual(MailFolder.inferKind(from: "[Gmail]/Sent Mail"), .sent)
        XCTAssertEqual(MailFolder.inferKind(from: "[Gmail]/All Mail"), .all)
        XCTAssertEqual(MailFolder.inferKind(from: "Mail/Sent Items"), .sent)
        XCTAssertEqual(MailFolder.inferKind(from: "自定义文件夹"), .other)
    }

    func testFolderNameFromPath() {
        let folder = MailFolder(path: "[Gmail]/Sent Mail", delimiter: "/")
        XCTAssertEqual(folder.name, "Sent Mail")
        XCTAssertEqual(folder.id, "[Gmail]/Sent Mail")
    }

    func testFolderRoundTrip() throws {
        let folder = MailFolder(path: "INBOX", kind: .inbox, unreadCount: 3)
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(MailFolder.self, from: data)
        XCTAssertEqual(decoded, folder)
    }

    // MARK: - MailMessageSummary

    func testSummaryRoundTrip() throws {
        let summary = MailMessageSummary(
            accountID: UUID(),
            folder: "INBOX",
            uid: 42,
            messageID: "<msg-42@example.com>",
            subject: "Hello",
            from: MailAddress(displayName: "A", email: "a@b.com"),
            to: [MailAddress(displayName: nil, email: "me@b.com")],
            date: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: true,
            isFlagged: false,
            hasAttachment: true,
            snippet: "Hi there",
            references: ["<r1@example.com>"]
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(MailMessageSummary.self, from: data)
        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(decoded.id, "\(summary.accountID.uuidString):INBOX:42")
    }

    // MARK: - MailError

    func testMailErrorRoundTrip() throws {
        let errors: [MailError] = [
            .authFailed, .network, .protocolError("x"), .notFound, .offline, .unsupported("oauth2"),
        ]
        for error in errors {
            let data = try JSONEncoder().encode(error)
            let decoded = try JSONDecoder().decode(MailError.self, from: data)
            XCTAssertEqual(decoded, error)
        }
    }

    func testMailErrorLocalizationKeys() {
        XCTAssertEqual(MailError.authFailed.localizedDescriptionKey, "Mail.Error.AuthFailed")
        XCTAssertEqual(MailError.offline.localizedDescriptionKey, "Mail.Error.Offline")
        XCTAssertFalse(MailError.network.fallbackDescription.isEmpty)
        XCTAssertEqual(MailError.authFailed.logLabel, "authFailed")
    }
}
