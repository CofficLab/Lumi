import Foundation

/// 邮件列表条目（摘要）。
///
/// 对应 MailCore `MCOIMAPMessage` 的轻量投影；正文在 `fetchBody` 时单独获取。
/// `uid` + `folder` 复合唯一；本地缓存以 `accountID + folder + uid` 唯一。
public struct MailMessageSummary: Sendable, Codable, Hashable, Identifiable {
    public var accountID: UUID
    public var folder: String
    public var uid: UInt64
    public var messageID: String?
    public var subject: String
    public var from: MailAddress?
    public var to: [MailAddress]
    public var date: Date
    public var isRead: Bool
    public var isFlagged: Bool
    public var hasAttachment: Bool
    public var snippet: String?
    /// `References` / `In-Reply-To` 头（回复引用线程用）
    public var references: [String]

    public init(
        accountID: UUID,
        folder: String,
        uid: UInt64,
        messageID: String? = nil,
        subject: String = "",
        from: MailAddress? = nil,
        to: [MailAddress] = [],
        date: Date = .distantPast,
        isRead: Bool = false,
        isFlagged: Bool = false,
        hasAttachment: Bool = false,
        snippet: String? = nil,
        references: [String] = []
    ) {
        self.accountID = accountID
        self.folder = folder
        self.uid = uid
        self.messageID = messageID
        self.subject = subject
        self.from = from
        self.to = to
        self.date = date
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.hasAttachment = hasAttachment
        self.snippet = snippet
        self.references = references
    }

    public var id: String { "\(accountID.uuidString):\(folder):\(uid)" }
}
