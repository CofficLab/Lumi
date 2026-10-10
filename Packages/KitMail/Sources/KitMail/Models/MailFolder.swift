import Foundation

/// 文件夹语义分类。`path` 未知时归为 `.other`。
///
/// 由路径 + 服务商惯例推断（INBOX / Sent / Drafts / Trash / Junk / Archive…），
/// 推断逻辑在 `MailFolder.inferKind(from:)`。
public enum MailFolderKind: String, Sendable, Codable, Hashable {
    case inbox
    case sent
    case drafts
    case trash
    case junk
    case archive
    case all
    case other
}

/// IMAP 文件夹节点。
public struct MailFolder: Sendable, Codable, Hashable, Identifiable {
    /// 服务器端完整路径（如 `INBOX`、`[Gmail]/Sent Mail`）
    public var path: String
    /// 显示名（路径最后一段）
    public var name: String
    /// 语义分类
    public var kind: MailFolderKind
    /// 路径分隔符（服务端下发，如 `/` 或 `.`；用 String 便于 Codable）
    public var delimiter: String
    /// 未读数（仅 `fetchFolders` 带回时非 nil）
    public var unreadCount: Int?

    public init(
        path: String,
        name: String? = nil,
        kind: MailFolderKind = .other,
        delimiter: String = "/",
        unreadCount: Int? = nil
    ) {
        self.path = path
        self.name = name ?? path.components(separatedBy: delimiter).last ?? path
        self.kind = kind
        self.delimiter = delimiter
        self.unreadCount = unreadCount
    }

    public var id: String { path }

    /// 按路径 + 关键字推断语义分类。
    public static func inferKind(from path: String) -> MailFolderKind {
        let lower = path.lowercased()
        let last = lower.components(separatedBy: CharacterSet(charactersIn: "/.")).last ?? lower
        switch last {
        case "inbox", "in":
            return .inbox
        case "sent", "sent mail", "sent items", "已发送", "已发送邮件", "寄件備份":
            return .sent
        case "drafts", "draft", "草稿":
            return .drafts
        case "trash", "deleted", "deleted items", "bin", "垃圾邮件", "已删除", "垃圾桶":
            return .trash
        case "junk", "spam", "垃圾箱", "垃圾郵件":
            return .junk
        case "archive", "archives", "归档", "封存":
            return .archive
        case "all mail", "all", "全部邮件", "所有邮件":
            return .all
        default:
            // 服务商标记型路径：[Gmail]/Sent Mail 等
            if lower.hasPrefix("[gmail]/") {
                if lower.contains("sent") { return .sent }
                if lower.contains("draft") { return .drafts }
                if lower.contains("trash") || lower.contains("bin") { return .trash }
                if lower.contains("spam") || lower.contains("junk") { return .junk }
                if lower.contains("archive") { return .archive }
                if lower.contains("all") { return .all }
            }
            if lower.hasPrefix("mail/") { // Outlook 风格
                if lower.hasPrefix("mail/sent") { return .sent }
                if lower.hasPrefix("mail/drafts") { return .drafts }
                if lower.hasPrefix("mail/deleted") { return .trash }
                if lower.hasPrefix("mail/junk") { return .junk }
                if lower.hasPrefix("mail/archive") { return .archive }
            }
            return .other
        }
    }
}
