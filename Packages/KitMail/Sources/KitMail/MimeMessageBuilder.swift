import Foundation
import MailCore

/// 待构建邮件草稿（只依赖 KitMail 模型，不暴露 MailCore 类型）。
public struct MimeMessageDraft: Sendable {
    public var from: MailAddress
    public var to: [MailAddress]
    public var cc: [MailAddress]
    public var bcc: [MailAddress]
    public var subject: String
    /// HTML 正文（富文本；与纯文本一起组成 multipart/alternative）
    public var htmlBody: String?
    /// 纯文本正文（multipart/alternative 的 text/plain 分支；必需）
    public var plainTextBody: String
    public var attachments: [MimeAttachmentData]
    /// 回复目标 Message-ID（写入 In-Reply-To 头）
    public var inReplyTo: String?
    /// 线程引用链（写入 References 头）
    public var references: [String]

    public init(
        from: MailAddress,
        to: [MailAddress],
        cc: [MailAddress] = [],
        bcc: [MailAddress] = [],
        subject: String,
        htmlBody: String? = nil,
        plainTextBody: String,
        attachments: [MimeAttachmentData] = [],
        inReplyTo: String? = nil,
        references: [String] = []
    ) {
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.htmlBody = htmlBody
        self.plainTextBody = plainTextBody
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.references = references
    }
}

/// 附件载荷（构建时读取进 MIME）。
public struct MimeAttachmentData: Sendable {
    public var filename: String
    public var mimeType: String
    public var data: Data

    public init(filename: String, mimeType: String, data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }
}

/// MIME 消息构建器。
///
/// 用 MailCore `MCOMessageBuilder` 生成符合 RFC 5322 / 2045 的原始字节：
/// - 有 HTML 时输出 multipart/alternative（text/plain + text/html）；
/// - 有附件时升级为 multipart/mixed；
/// - 回复时写入 In-Reply-To / References 头。
public enum MimeMessageBuilder {
    /// 构建完整 MIME 原始数据（可直接用于 SMTP 发送 / 草稿 APPEND）。
    public static func build(_ draft: MimeMessageDraft) throws -> Data {
        let builder = MCOMessageBuilder()
        builder.header.from = address(draft.from)
        builder.header.to = draft.to.map(address)
        builder.header.cc = draft.cc.map(address)
        builder.header.bcc = draft.bcc.map(address)
        builder.header.subject = draft.subject
        builder.htmlBody = draft.htmlBody
        builder.textBody = draft.plainTextBody
        if let inReplyTo = draft.inReplyTo {
            builder.header.inReplyTo = [inReplyTo]
        }
        if !draft.references.isEmpty {
            builder.header.references = draft.references
        }
        for attachment in draft.attachments {
            if let mco = attachmentData(attachment) {
                builder.addAttachment(mco)
            }
        }
        guard let data = builder.data() else {
            throw MailError.protocolError("MIME serialization failed")
        }
        return data
    }

    /// 生成回复引用正文：
    /// `On <date>, <from> wrote:` + 原文每行加 `> ` 前缀。
    /// 传入原文的纯文本正文（HTML 邮件先做纯文本降级）。
    public static func quotedReplyText(
        originalDate: Date?,
        originalFrom: MailAddress?,
        originalBody: String?
    ) -> String {
        var lines = ["On \(formatDate(originalDate)), \(originalFrom?.rfc5322 ?? "the sender") wrote:"]
        if let originalBody {
            for line in originalBody.components(separatedBy: "\n") {
                lines.append("> \(line)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// 从原信计算回复的 References 链（RFC 5322 线程规范）：
    /// 若原信已有 references，追加原信 Message-ID；否则以原信 Message-ID 起头。
    public static func replyReferences(
        originalReferences: [String],
        originalMessageID: String?
    ) -> [String] {
        var refs = originalReferences
        if let messageID = originalMessageID, !refs.contains(messageID) {
            refs.append(messageID)
        }
        return refs
    }

    // MARK: - 内部映射

    private static func address(_ address: MailAddress) -> MCOAddress {
        if let displayName = address.displayName, !displayName.isEmpty {
            return MCOAddress(displayName: displayName, mailbox: address.email)
        }
        return MCOAddress(mailbox: address.email)
    }

    private static func attachmentData(_ attachment: MimeAttachmentData) -> MCOAttachment? {
        guard let mco = MCOAttachment(data: attachment.data, filename: attachment.filename) else {
            return nil
        }
        mco.mimeType = attachment.mimeType
        return mco
    }

    private static func formatDate(_ date: Date?) -> String {
        guard let date else { return "unknown time" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm Z"
        return formatter.string(from: date)
    }
}
