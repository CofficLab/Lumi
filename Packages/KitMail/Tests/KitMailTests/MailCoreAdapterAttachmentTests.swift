import XCTest
import MailCore
@testable import KitMail

/// 回归 #844：MIME 的 `Content-Disposition: attachment` 不要求 filename，
/// 缺失（nil）或空文件名的合法附件不得被 `mail_read_message` 丢弃，
/// 而应生成确定性回退名并保留数据。
final class MailCoreAdapterAttachmentTests: XCTestCase {
    private func makeAdapter() -> MailCoreAdapter {
        let config = MailAccountConfig(
            displayName: "Test",
            email: "test@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "test@example.com"
        )
        // 内联附件映射不触网；会话仅在 connect() 后才建立连接。
        return MailCoreAdapter(account: config, password: "unused")
    }

    /// 构造 multipart/mixed 原始 MIME：一个 text/plain 正文 + 若干附件 part。
    /// `filename` 为 nil 时不写 filename 参数，复现 #844 的无名附件。
    private func makeMIME(
        attachments: [(filename: String?, mimeType: String, payload: Data)]
    ) -> Data {
        let boundary = "----LumiKitMailAttachmentBoundary"
        var lines: [String] = [
            "From: sender@example.com",
            "To: rcpt@example.com",
            "Subject: Attachment test",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"\(boundary)\"",
            "",
            "--\(boundary)",
            "Content-Type: text/plain; charset=\"utf-8\"",
            "",
            "Body text",
        ]
        for attachment in attachments {
            lines.append("--\(boundary)")
            lines.append("Content-Type: \(attachment.mimeType)")
            if let filename = attachment.filename {
                lines.append("Content-Disposition: attachment; filename=\"\(filename)\"")
            } else {
                lines.append("Content-Disposition: attachment")
            }
            lines.append("Content-Transfer-Encoding: base64")
            lines.append("")
            lines.append(attachment.payload.base64EncodedString())
        }
        lines.append("--\(boundary)--")
        lines.append("")
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    private func parse(_ data: Data) throws -> MCOMessageParser {
        try XCTUnwrap(MCOMessageParser(data: data), "MCOMessageParser failed to parse MIME")
    }

    func testFetchAttachmentsKeepsFilenamelessAttachment() async throws {
        let payload = Data("ATTACHMENT-BYTES-844".utf8)
        let parser = try parse(makeMIME(attachments: [
            (filename: nil, mimeType: "application/octet-stream", payload: payload)
        ]))
        // sanity：解析器确实把无名 part 识别为附件（由 Content-Disposition 决定）。
        let parts = parser.attachments() as? [MCOAbstractPart] ?? []
        XCTAssertEqual(parts.count, 1, "解析器应识别出无名附件 part")

        let result = try await makeAdapter().fetchAttachments(for: parser, uid: 1, folder: "INBOX")
        XCTAssertEqual(result.count, 1, "无名附件不得被丢弃")
        XCTAssertEqual(result.first?.filename, "attachment_1")
        XCTAssertEqual(result.first?.mimeType, "application/octet-stream")
        XCTAssertEqual(result.first?.data, payload)
        XCTAssertEqual(result.first?.size, Int64(payload.count))
    }

    func testFetchAttachmentsKeepsEmptyFilenameAttachment() async throws {
        let payload = Data("EMPTY-NAME".utf8)
        let parser = try parse(makeMIME(attachments: [
            (filename: "", mimeType: "application/pdf", payload: payload)
        ]))
        let result = try await makeAdapter().fetchAttachments(for: parser, uid: 2, folder: "INBOX")
        XCTAssertEqual(result.count, 1, "空文件名附件不得被丢弃")
        XCTAssertEqual(result.first?.filename, "attachment_1")
        XCTAssertEqual(result.first?.mimeType, "application/pdf")
        XCTAssertEqual(result.first?.data, payload)
    }

    func testFetchAttachmentsAssignsUniqueNamesToMultipleFilenamelessAttachments() async throws {
        let first = Data("FIRST".utf8)
        let second = Data("SECOND".utf8)
        let parser = try parse(makeMIME(attachments: [
            (filename: nil, mimeType: "application/octet-stream", payload: first),
            (filename: nil, mimeType: "application/octet-stream", payload: second)
        ]))
        let result = try await makeAdapter().fetchAttachments(for: parser, uid: 3, folder: "INBOX")
        XCTAssertEqual(result.count, 2, "两个无名附件都应保留")
        XCTAssertEqual(result.map(\.filename), ["attachment_1", "attachment_2"])
        XCTAssertEqual(Set(result.map(\.filename)).count, 2, "回退名不得互相覆盖")
        XCTAssertEqual(result.first?.data, first)
        XCTAssertEqual(result.last?.data, second)
    }

    func testFetchAttachmentsPreservesNamedAttachmentAndOrder() async throws {
        let named = Data("NAMED-PDF".utf8)
        let unnamed = Data("UNNAMED".utf8)
        let parser = try parse(makeMIME(attachments: [
            (filename: "report.pdf", mimeType: "application/pdf", payload: named),
            (filename: nil, mimeType: "application/octet-stream", payload: unnamed)
        ]))
        let result = try await makeAdapter().fetchAttachments(for: parser, uid: 4, folder: "INBOX")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.filename), ["report.pdf", "attachment_2"], "保留原名与原始顺序")
        XCTAssertEqual(result.first?.data, named)
        XCTAssertEqual(result.last?.data, unnamed)
    }
}