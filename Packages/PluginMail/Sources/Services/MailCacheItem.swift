import Foundation
import SwiftData
import KitMail

/// SwiftData 邮件缓存条目（`MailCacheService` 使用）。
///
/// 与 `MailMessageSummary` / `MailMessageDetail` 对应的扁平投影；
/// 以 `accountID + folder + uid` 唯一。正文与附件路径按需在读取时组装。
@Model
public final class MailCacheItem {
    public var accountID: UUID
    public var folder: String
    public var uid: UInt64
    public var messageID: String?
    public var subject: String
    public var fromDisplayName: String?
    public var fromEmail: String
    /// 收件人列表的 JSON 编码（`[MailAddress]` 的 Codable 投影）
    public var toJSON: String
    public var date: Date
    public var isRead: Bool
    public var isFlagged: Bool
    public var hasAttachment: Bool
    public var snippet: String?
    /// `References` / `In-Reply-To` 头（JSON 编码）
    public var referencesJSON: String
    public var htmlBody: String?
    public var plainTextBody: String?
    /// 首次缓存时间（同步/审计用）
    public var fetchedAt: Date

    public init(
        accountID: UUID,
        folder: String,
        uid: UInt64,
        messageID: String? = nil,
        subject: String = "",
        fromDisplayName: String? = nil,
        fromEmail: String = "",
        toJSON: String = "[]",
        date: Date = .distantPast,
        isRead: Bool = false,
        isFlagged: Bool = false,
        hasAttachment: Bool = false,
        snippet: String? = nil,
        referencesJSON: String = "[]",
        htmlBody: String? = nil,
        plainTextBody: String? = nil,
        fetchedAt: Date = .now
    ) {
        self.accountID = accountID
        self.folder = folder
        self.uid = uid
        self.messageID = messageID
        self.subject = subject
        self.fromDisplayName = fromDisplayName
        self.fromEmail = fromEmail
        self.toJSON = toJSON
        self.date = date
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.hasAttachment = hasAttachment
        self.snippet = snippet
        self.referencesJSON = referencesJSON
        self.htmlBody = htmlBody
        self.plainTextBody = plainTextBody
        self.fetchedAt = fetchedAt
    }

    /// 跨 actor 返回的安全投影（`MailCacheService` 对外暴露用）。
    public struct Summary: Sendable, Equatable {
        public var uid: UInt64
        public var subject: String
        public var fromDisplayName: String?
        public var fromEmail: String
        public var date: Date
        public var isRead: Bool
        public var isFlagged: Bool
        public var hasAttachment: Bool
        public var snippet: String?
    }

    public var summaryProjection: Summary {
        Summary(
            uid: uid,
            subject: subject,
            fromDisplayName: fromDisplayName,
            fromEmail: fromEmail,
            date: date,
            isRead: isRead,
            isFlagged: isFlagged,
            hasAttachment: hasAttachment,
            snippet: snippet
        )
    }
}
