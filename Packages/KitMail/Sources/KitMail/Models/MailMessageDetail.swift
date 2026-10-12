import Foundation

/// 邮件正文详情（阅读窗格渲染所需）。
///
/// `htmlBody` 与 `plainTextBody` 至少其一非 nil：
/// - 富文本邮件两者都有（渲染 HTML，纯文本降级）；
/// - 纯文本邮件仅 `plainTextBody`。
public struct MailMessageDetail: Sendable, Codable, Hashable {
    public var summary: MailMessageSummary
    public var htmlBody: String?
    public var plainTextBody: String?
    public var attachments: [MailAttachment]
    public var inReplyTo: String?

    public init(
        summary: MailMessageSummary,
        htmlBody: String? = nil,
        plainTextBody: String? = nil,
        attachments: [MailAttachment] = [],
        inReplyTo: String? = nil
    ) {
        self.summary = summary
        self.htmlBody = htmlBody
        self.plainTextBody = plainTextBody
        self.attachments = attachments
        self.inReplyTo = inReplyTo
    }
}
