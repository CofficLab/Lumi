import Foundation
import KitAgentTool
import KitMail

/// Mail Agent 工具服务：账户/列表/阅读/搜索/发送的共享执行入口。
///
/// 工具分级：list/read/search = `.safe`（只读，可并行），send = `.high`（审批）。
public actor MailAgentToolService {
    private let sessionManager: MailSessionManager
    private let cache: MailCacheService
    private let composer: MailComposerService

    public init(
        sessionManager: MailSessionManager,
        cache: MailCacheService,
        composer: MailComposerService
    ) {
        self.sessionManager = sessionManager
        self.cache = cache
        self.composer = composer
    }

    // MARK: - 账户

    /// 列出账户（无凭据信息）。默认选中第一个账户的 INBOX。
    public func listAccounts() -> String {
        let accounts = MailAccountStore.loadAccounts()
        guard !accounts.isEmpty else {
            return "没有可用的邮件账户。请先在「设置 → 邮件」添加账户。"
        }
        let lines = accounts.map { account in
            "- id: \(account.id.uuidString), 邮箱: \(account.email), 显示名: \(account.displayName)"
        }
        return "可用邮件账户：\n" + lines.joined(separator: "\n")
    }

    /// 列出某账户某文件夹最近邮件摘要。
    public func listMessages(
        accountID: UUID?,
        folder: String,
        limit: Int
    ) async throws -> String {
        let account: MailAccountConfig
        do {
            account = try accountFor(accountID)
        } catch MailError.notFound {
            return "没有可用的邮件账户。请先在「设置 → 邮件」添加账户。"
        } catch {
            throw error
        }
        // 同步增量（离线时用缓存兜底）
        let session = try await sessionManager.session(for: account)
        do {
            let summaries = try await session.fetchMessages(
                folder: folder,
                sinceUID: nil,
                limit: limit
            )
            try await cache.upsertMessages(summaries, accountID: account.id, folder: folder)
        } catch {
            // 离线降级：继续读缓存
        }
        let items = try await cache.messages(accountID: account.id, folder: folder)
        let recent = items.suffix(limit).reversed()
        guard !recent.isEmpty else {
            return "「\(folder)」暂无邮件。"
        }
        var lines = ["账户 \(account.email) / \(folder) 最近 \(recent.count) 封邮件："]
        for item in recent {
            lines.append("- uid=\(item.uid) \(unreadMarker(item))「\(item.subject.isEmpty ? "(无主题)" : item.subject)」 \(sender(item)) \(item.date.formatted(date: .abbreviated, time: .shortened))")
        }
        lines.append("提示：用 mail_read_message 传入 uid 读取正文。")
        return lines.joined(separator: "\n")
    }

    /// 读取单封邮件正文（HTML 转纯文本摘要展示）。
    public func readMessage(
        accountID: UUID?,
        folder: String,
        uid: UInt64
    ) async throws -> String {
        let account = try accountFor(accountID)
        let session = try await sessionManager.session(for: account)
        let detail = try await session.fetchBody(uid: uid, folder: folder)
        try await cache.upsertDetail(detail, accountID: account.id, folder: folder)
        // 阅读即已读：缓存 + 服务端同步
        try await session.setFlags(uid: uid, folder: folder, isRead: true, isFlagged: nil)
        try await cache.setFlags(
            accountID: account.id, folder: folder, uid: uid,
            isRead: true, isFlagged: nil
        )

        var lines: [String] = []
        lines.append("主题：\(detail.summary.subject.isEmpty ? "(无主题)" : detail.summary.subject)")
        lines.append("发件人：\(detail.summary.from?.rfc5322 ?? "未知")")
        lines.append("时间：\(detail.summary.date.formatted(date: .long, time: .shortened))")
        if !detail.summary.to.isEmpty {
            lines.append("收件人：\(detail.summary.to.map(\.rfc5322).joined(separator: ", "))")
        }
        lines.append("")
        if let body = detail.plainTextBody, !body.isEmpty {
            lines.append(body)
        } else if let html = detail.htmlBody, !html.isEmpty {
            lines.append(plainTextFromHTML(html))
        } else {
            lines.append("（无正文）")
        }
        if !detail.attachments.isEmpty {
            lines.append("")
            lines.append("附件：\(detail.attachments.map(\.filename).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    /// 本地缓存搜索（离线可用）。
    public func searchMessages(
        accountID: UUID?,
        folder: String?,
        query: String
    ) async throws -> String {
        let account = try accountFor(accountID)
        let hits = try await cache.search(accountID: account.id, folder: folder, query: query)
        guard !hits.isEmpty else {
            return "没有找到匹配「\(query)」的邮件。"
        }
        var lines = ["匹配「\(query)」的邮件（\(hits.count) 封）："]
        for item in hits.prefix(50) {
            lines.append("- uid=\(item.uid)「\(item.subject)」 \(sender(item))")
        }
        return lines.joined(separator: "\n")
    }

    /// 发送邮件（高风险，审批通过后执行）。
    public func sendMessage(
        accountID: UUID?,
        to: String,
        subject: String,
        body: String
    ) async throws -> String {
        let account = try accountFor(accountID)
        let recipients = to.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !recipients.isEmpty else {
            throw MailError.protocolError("收件人不能为空。")
        }
        let draft = MimeMessageDraft(
            from: MailAddress(displayName: account.displayName, email: account.email),
            to: recipients.map { MailAddress(displayName: nil, email: String($0)) },
            subject: subject,
            plainTextBody: body
        )
        try await composer.send(draft: draft, account: account)
        return "邮件已发送：至 \(recipients.joined(separator: ", "))，主题「\(subject)」。"
    }

    // MARK: - 私有

    private func accountFor(_ accountID: UUID?) throws -> MailAccountConfig {
        let accounts = MailAccountStore.loadAccounts()
        if let id = accountID {
            if let account = accounts.first(where: { $0.id == id }) {
                return account
            }
            throw MailError.notFound
        }
        guard let first = accounts.first else {
            throw MailError.notFound
        }
        return first
    }

    private func unreadMarker(_ item: MailCacheItem.Summary) -> String {
        item.isRead ? "·" : "【未读】"
    }

    private func sender(_ item: MailCacheItem.Summary) -> String {
        if let name = item.fromDisplayName, !name.isEmpty {
            return "\(name) <\(item.fromEmail)>"
        }
        return item.fromEmail
    }

    /// 极简 HTML → 纯文本（标签剥离 + 实体解码），供工具文本展示。
    private func plainTextFromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        let lines = text.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - 工具

/// mail_list_messages：列出最近邮件（safe，可并行只读）。
public struct MailListMessagesTool: SuperAgentTool {
    public static let toolName = "mail_list_messages"
    public let name = Self.toolName
    private let service: MailAgentToolService

    public init(service: MailAgentToolService) {
        self.service = service
    }

    public func description(for language: LanguagePreference) -> String {
        "List recent messages in a mail folder (default INBOX) for the given account. Returns uid, subject, sender, date, read state."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        MailToolSupport.schema(
            properties: [
                "account_id": MailToolSupport.string("Account UUID from mail_list_accounts; optional, defaults to the first account."),
                "folder": MailToolSupport.string("IMAP folder path; default INBOX."),
                "limit": MailToolSupport.integer("Max messages to return; default 10, max 50."),
            ],
            required: []
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "列出邮件（\(MailToolSupport.optionalString(arguments, "folder") ?? "INBOX")）"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await service.listMessages(
            accountID: MailToolSupport.optionalUUID(arguments, "account_id"),
            folder: MailToolSupport.optionalString(arguments, "folder") ?? "INBOX",
            limit: MailToolSupport.optionalInt(arguments, "limit") ?? 10
        )
    }
}

/// mail_read_message：读取单封正文（safe）。
public struct MailReadMessageTool: SuperAgentTool {
    public static let toolName = "mail_read_message"
    public let name = Self.toolName
    private let service: MailAgentToolService

    public init(service: MailAgentToolService) {
        self.service = service
    }

    public func description(for language: LanguagePreference) -> String {
        "Read the full body of one message by folder path and uid. Marks the message as read."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        MailToolSupport.schema(
            properties: [
                "account_id": MailToolSupport.string("Account UUID from mail_list_accounts; optional, defaults to the first account."),
                "folder": MailToolSupport.string("IMAP folder path; default INBOX."),
                "uid": MailToolSupport.integer("Message uid returned by mail_list_messages."),
            ],
            required: ["uid"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "读取邮件（uid=\(MailToolSupport.optionalInt(arguments, "uid") ?? 0)）"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let uid = MailToolSupport.optionalInt(arguments, "uid") else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "缺少必需参数: uid")
        }
        return try await service.readMessage(
            accountID: MailToolSupport.optionalUUID(arguments, "account_id"),
            folder: MailToolSupport.optionalString(arguments, "folder") ?? "INBOX",
            uid: UInt64(uid)
        )
    }
}

/// mail_search_messages：本地缓存搜索（safe，离线可用）。
public struct MailSearchMessagesTool: SuperAgentTool {
    public static let toolName = "mail_search_messages"
    public let name = Self.toolName
    private let service: MailAgentToolService

    public init(service: MailAgentToolService) {
        self.service = service
    }

    public func description(for language: LanguagePreference) -> String {
        "Search cached mail locally by keyword across subject, sender, snippet and body. Works offline."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        MailToolSupport.schema(
            properties: [
                "account_id": MailToolSupport.string("Account UUID; optional, defaults to the first account."),
                "folder": MailToolSupport.string("Optional IMAP folder to restrict the search."),
                "query": MailToolSupport.string("Search keyword."),
            ],
            required: ["query"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "搜索邮件（\(MailToolSupport.optionalString(arguments, "query") ?? "")）"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let query = MailToolSupport.optionalString(arguments, "query") else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "缺少必需参数: query")
        }
        return try await service.searchMessages(
            accountID: MailToolSupport.optionalUUID(arguments, "account_id"),
            folder: MailToolSupport.optionalString(arguments, "folder"),
            query: query
        )
    }
}

/// mail_send_message：发送邮件（high，需审批）。
public struct MailSendMessageTool: SuperAgentTool {
    public static let toolName = "mail_send_message"
    public let name = Self.toolName
    private let service: MailAgentToolService

    public init(service: MailAgentToolService) {
        self.service = service
    }

    public func description(for language: LanguagePreference) -> String {
        "Send an email from a configured account. Requires explicit user approval. Draft summary is shown for review before sending."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        MailToolSupport.schema(
            properties: [
                "account_id": MailToolSupport.string("Account UUID from mail_list_accounts; optional, defaults to the first account."),
                "to": MailToolSupport.string("Comma-separated recipient addresses."),
                "subject": MailToolSupport.string("Email subject."),
                "body": MailToolSupport.string("Plain text body."),
            ],
            required: ["to", "subject", "body"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "发送邮件至 \(MailToolSupport.optionalString(arguments, "to") ?? "")"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .high }

    public func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool { true }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let to = MailToolSupport.optionalString(arguments, "to"),
              let subject = MailToolSupport.optionalString(arguments, "subject"),
              let body = MailToolSupport.optionalString(arguments, "body") else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "缺少必需参数: to/subject/body")
        }
        return try await service.sendMessage(
            accountID: MailToolSupport.optionalUUID(arguments, "account_id"),
            to: to,
            subject: subject,
            body: body
        )
    }
}

// MARK: - 参数与 Schema 辅助

private enum MailToolSupport {
    static func schema(properties: [String: Any], required: [String]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": required]
    }

    static func string(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    static func integer(_ description: String) -> [String: Any] {
        ["type": "integer", "description": description]
    }

    static func optionalString(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value else { return nil }
        return value as? String
    }

    static func optionalInt(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let int = value as? Int64 { return Int(int) }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func optionalUUID(_ arguments: [String: ToolArgument], _ key: String) -> UUID? {
        guard let string = optionalString(arguments, key) else { return nil }
        return UUID(uuidString: string)
    }
}
