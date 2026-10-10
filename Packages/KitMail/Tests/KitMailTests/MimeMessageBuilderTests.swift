import XCTest
import MailCore
@testable import KitMail

final class MimeMessageBuilderTests: XCTestCase {
    private var draft: MimeMessageDraft {
        MimeMessageDraft(
            from: MailAddress(displayName: "张三", email: "me@example.com"),
            to: [MailAddress(displayName: "Alice", email: "alice@example.com")],
            cc: [MailAddress(displayName: nil, email: "cc@example.com")],
            bcc: [MailAddress(displayName: nil, email: "bcc@example.com")],
            subject: "Test 主题",
            htmlBody: "<html><body><b>Hello</b> 世界</body></html>",
            plainTextBody: "Hello 世界\n第二行",
            attachments: [
                MimeAttachmentData(
                    filename: "报告.pdf",
                    mimeType: "application/pdf",
                    data: Data("PDF-BINARY-123".utf8)
                )
            ]
        )
    }

    func testBuildAndParseRoundTrip() throws {
        let data = try MimeMessageBuilder.build(draft)
        XCTAssertFalse(data.isEmpty)

        guard let parser = MCOMessageParser(data: data),
              let header = parser.header else {
            XCTFail("MCOMessageParser failed to parse built message")
            return
        }

        XCTAssertEqual(header.subject, "Test 主题")
        XCTAssertEqual(header.from?.mailbox, "me@example.com")
        XCTAssertEqual(header.from?.displayName, "张三")
        XCTAssertEqual(header.to.count, 1)
        XCTAssertEqual(header.to.first?.mailbox, "alice@example.com")
        XCTAssertEqual(header.cc.count, 1)
        XCTAssertEqual(header.bcc.count, 1)

        let plain = parser.plainTextRendering() ?? ""
        XCTAssertTrue(plain.contains("Hello 世界"), "plain body missing: \(plain)")

        let html = parser.htmlRendering(with: nil) ?? ""
        XCTAssertTrue(html.contains("<b>Hello</b>") || html.contains("Hello"), "html body missing")

        let attachments = parser.attachments() as? [MCOAttachment] ?? []
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments.first?.filename, "报告.pdf")
        let attachmentData = attachments.first?.data ?? Data()
        XCTAssertEqual(String(data: attachmentData, encoding: .utf8), "PDF-BINARY-123")
    }

    func testPlainOnlyBuild() throws {
        let plainDraft = MimeMessageDraft(
            from: MailAddress(displayName: nil, email: "a@b.com"),
            to: [MailAddress(displayName: nil, email: "c@d.com")],
            subject: "Plain",
            plainTextBody: "Only plain text"
        )
        let data = try MimeMessageBuilder.build(plainDraft)
        guard let parser = MCOMessageParser(data: data) else {
            XCTFail("parse failed")
            return
        }
        XCTAssertEqual(parser.header.subject, "Plain")
        XCTAssertTrue((parser.plainTextRendering() ?? "").contains("Only plain text"))
        XCTAssertEqual((parser.attachments() as? [MCOAbstractPart] ?? []).count, 0)
    }

    func testReplyHeaders() throws {
        let replyDraft = MimeMessageDraft(
            from: MailAddress(displayName: nil, email: "a@b.com"),
            to: [MailAddress(displayName: nil, email: "c@d.com")],
            subject: "Re: Original",
            plainTextBody: "Reply body",
            inReplyTo: "<orig-1@example.com>",
            references: ["<ancestor@example.com>", "<orig-1@example.com>"]
        )
        let data = try MimeMessageBuilder.build(replyDraft)
        guard let header = MCOMessageParser(data: data)?.header else {
            XCTFail("parse failed")
            return
        }
        // MailCore 将 In-Reply-To / References 规范化存储为不带尖括号的 message-id
        XCTAssertEqual(header.inReplyTo as? [String], ["orig-1@example.com"])
        XCTAssertEqual(
            header.references as? [String],
            ["ancestor@example.com", "orig-1@example.com"]
        )
    }

    func testQuotedReplyText() {
        let quoted = MimeMessageBuilder.quotedReplyText(
            originalDate: Date(timeIntervalSince1970: 1_700_000_000),
            originalFrom: MailAddress(displayName: "Alice", email: "alice@example.com"),
            originalBody: "line1\nline2"
        )
        XCTAssertTrue(quoted.contains("wrote:"))
        XCTAssertTrue(quoted.contains("> line1"))
        XCTAssertTrue(quoted.contains("> line2"))
    }

    func testReplyReferencesChain() {
        // 原信已有 references → 追加 messageID
        let refs = MimeMessageBuilder.replyReferences(
            originalReferences: ["<r1@example.com>"],
            originalMessageID: "<m2@example.com>"
        )
        XCTAssertEqual(refs, ["<r1@example.com>", "<m2@example.com>"])

        // 无 references → 以 messageID 起头
        let refs2 = MimeMessageBuilder.replyReferences(
            originalReferences: [],
            originalMessageID: "<m3@example.com>"
        )
        XCTAssertEqual(refs2, ["<m3@example.com>"])

        // messageID 已在 references 中 → 不重复
        let refs3 = MimeMessageBuilder.replyReferences(
            originalReferences: ["<m4@example.com>"],
            originalMessageID: "<m4@example.com>"
        )
        XCTAssertEqual(refs3, ["<m4@example.com>"])
    }
}
