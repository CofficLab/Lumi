import Foundation
import SwiftData
import KitMail

/// 邮件缓存服务（actor + SwiftData）。
///
/// - 以 `accountID + folder + uid` 唯一存取摘要与正文；
/// - 提供未读计数（Phase 3 文件夹树）与 LIKE 全文搜索（Phase 5 离线搜索先行）；
/// - 数据库目录在初始化时注入（测试传临时目录，生产用 `MailPluginRuntime`）。
public actor MailCacheService {
    private let container: ModelContainer

    /// - Parameter databaseDirectory: 数据库目录（含 `mailcache.sqlite`）。
    public init(databaseDirectory: URL) {
        let schema = Schema([MailCacheItem.self])
        let dbURL = databaseDirectory.appendingPathComponent("mailcache.sqlite")
        do {
            try FileManager.default.createDirectory(
                at: databaseDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            // 目录创建失败会在下方配置构造时抛出，由调用方处理。
        }
        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        self.container = try! ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - 写入

    /// 批量 upsert 摘要（同一 accountID+folder+uid 覆盖，保留正文已有内容）。
    public func upsertMessages(
        _ summaries: [MailMessageSummary],
        accountID: UUID,
        folder: String
    ) throws {
        let context = ModelContext(container)
        for summary in summaries {
            try upsertOne(summary, accountID: accountID, folder: folder, in: context)
        }
        try context.save()
    }

    /// 写回单封邮件正文（读取后缓存 HTML/纯文本）。
    public func upsertDetail(_ detail: MailMessageDetail, accountID: UUID, folder: String) throws {
        let context = ModelContext(container)
        if let existing = try find(
            accountID: accountID,
            folder: folder,
            uid: detail.summary.uid,
            in: context
        ) {
            existing.htmlBody = detail.htmlBody
            existing.plainTextBody = detail.plainTextBody
            existing.hasAttachment = !detail.attachments.isEmpty
            existing.fetchedAt = .now
        } else {
            let item = MailCacheItem(from: detail.summary, accountID: accountID, folder: folder)
            item.htmlBody = detail.htmlBody
            item.plainTextBody = detail.plainTextBody
            context.insert(item)
        }
        try context.save()
    }

    /// 更新未读/星标（本地已读、客户端操作后写回缓存）。
    public func setFlags(
        accountID: UUID,
        folder: String,
        uid: UInt64,
        isRead: Bool?,
        isFlagged: Bool?
    ) throws {
        let context = ModelContext(container)
        if let existing = try find(accountID: accountID, folder: folder, uid: uid, in: context) {
            if let isRead { existing.isRead = isRead }
            if let isFlagged { existing.isFlagged = isFlagged }
            existing.fetchedAt = .now
            try context.save()
        }
    }

    /// 删除该 folder 中不在 `keepUIDs` 集合里的条目（远端已删除时调用）。
    @discardableResult
    public func removeMessages(
        accountID: UUID,
        folder: String,
        keeping keepUIDs: Set<UInt64>
    ) throws -> Int {
        let context = ModelContext(container)
        let items = try fetchAll(accountID: accountID, folder: folder, in: context)
        var removed = 0
        for item in items where !keepUIDs.contains(item.uid) {
            context.delete(item)
            removed += 1
        }
        if removed > 0 {
            try context.save()
        }
        return removed
    }

    /// 清空某账户缓存（删除账户时调用）。
    public func purge(accountID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate { $0.accountID == accountID }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
        try context.save()
    }

    // MARK: - 读取

    /// 该 folder 当前最大 uid（增量同步游标；无缓存时返回 0）。
    public func lastUID(accountID: UUID, folder: String) throws -> UInt64 {
        let context = ModelContext(container)
        let items = try fetchAll(accountID: accountID, folder: folder, in: context)
        return items.map(\.uid).max() ?? 0
    }

    /// 指定 uid 是否已缓存（同步统计新增/更新用）。
    public func contains(accountID: UUID, folder: String, uid: UInt64) throws -> Bool {
        let context = ModelContext(container)
        return try find(accountID: accountID, folder: folder, uid: uid, in: context) != nil
    }

    /// 该 folder 全部条目（按 uid 升序；Sendable 投影，供 UI/测试跨 actor 使用）。
    public func messages(accountID: UUID, folder: String) throws -> [MailCacheItem.Summary] {
        let context = ModelContext(container)
        let items = try fetchAll(accountID: accountID, folder: folder, in: context)
        return items
            .sorted { $0.uid < $1.uid }
            .map(\.summaryProjection)
    }

    /// 未读数（Phase 3 文件夹树徽标）。
    public func unreadCount(accountID: UUID, folder: String) throws -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate { $0.accountID == accountID && $0.folder == folder && !$0.isRead }
        )
        return try context.fetchCount(descriptor)
    }

    /// 该账户全部未读数（活动栏徽标）。
    public func totalUnreadCount(accountID: UUID) throws -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate { $0.accountID == accountID && !$0.isRead }
        )
        return try context.fetchCount(descriptor)
    }

    /// 本地 LIKE 搜索（标题/发件人/正文；Phase 5 离线搜索，先按最少功能原则取 LIKE）。
    /// SQL 层只按非空字段（subject/fromEmail）匹配；snippet/正文在内存中过滤，
    /// 避免 `?? ""` 生成 CoreData 不支持的 TERNARY 谓词。
    public func search(accountID: UUID, folder: String?, query: String) throws -> [MailCacheItem.Summary] {
        let context = ModelContext(container)
        let lower = query.lowercased()
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate<MailCacheItem> { item in
                item.accountID == accountID
                    && (folder == nil || item.folder == folder!)
                    && (item.subject.localizedStandardContains(lower)
                        || item.fromEmail.localizedStandardContains(lower))
            }
        )
        let sqlHits = try context.fetch(descriptor)
        let sqlUIDs = Set(sqlHits.map(\.uid))
        // 正文/snippet 命中不在 SQL 谓词内（CoreData 限制），用同一账户全量补扫合并。
        let bodyDescriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate {
                $0.accountID == accountID && (folder == nil || $0.folder == folder!)
            }
        )
        return try context.fetch(bodyDescriptor)
            .filter {
                sqlUIDs.contains($0.uid)
                    || ($0.snippet?.localizedStandardContains(lower) ?? false)
                    || ($0.plainTextBody?.localizedStandardContains(lower) ?? false)
            }
            .map(\.summaryProjection)
    }

    // MARK: - 私有

    private func upsertOne(
        _ summary: MailMessageSummary,
        accountID: UUID,
        folder: String,
        in context: ModelContext
    ) throws {
        if let existing = try find(
            accountID: accountID,
            folder: folder,
            uid: summary.uid,
            in: context
        ) {
            existing.subject = summary.subject
            existing.fromDisplayName = summary.from?.displayName
            existing.fromEmail = summary.from?.email ?? ""
            existing.toJSON = MailCacheItem.encodeAddresses(summary.to)
            existing.date = summary.date
            existing.isRead = summary.isRead
            existing.isFlagged = summary.isFlagged
            existing.hasAttachment = summary.hasAttachment
            existing.snippet = summary.snippet
            existing.referencesJSON = MailCacheItem.encodeStrings(summary.references)
            existing.messageID = summary.messageID
            existing.fetchedAt = .now
        } else {
            context.insert(MailCacheItem(from: summary, accountID: accountID, folder: folder))
        }
    }

    private func find(
        accountID: UUID,
        folder: String,
        uid: UInt64,
        in context: ModelContext
    ) throws -> MailCacheItem? {
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate {
                $0.accountID == accountID && $0.folder == folder && $0.uid == uid
            }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchAll(
        accountID: UUID,
        folder: String,
        in context: ModelContext
    ) throws -> [MailCacheItem] {
        let descriptor = FetchDescriptor<MailCacheItem>(
            predicate: #Predicate {
                $0.accountID == accountID && $0.folder == folder
            }
        )
        return try context.fetch(descriptor)
    }
}

// MARK: - 编码辅助

extension MailCacheItem {
    /// 从摘要构造缓存条目（正文留空，读取时补写）。
    convenience init(from summary: MailMessageSummary, accountID: UUID, folder: String) {
        self.init(
            accountID: accountID,
            folder: folder,
            uid: summary.uid,
            messageID: summary.messageID,
            subject: summary.subject,
            fromDisplayName: summary.from?.displayName,
            fromEmail: summary.from?.email ?? "",
            toJSON: MailCacheItem.encodeAddresses(summary.to),
            date: summary.date,
            isRead: summary.isRead,
            isFlagged: summary.isFlagged,
            hasAttachment: summary.hasAttachment,
            snippet: summary.snippet,
            referencesJSON: MailCacheItem.encodeStrings(summary.references)
        )
    }

    static func encodeAddresses(_ addresses: [MailAddress]) -> String {
        guard let data = try? JSONEncoder().encode(addresses) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func encodeStrings(_ strings: [String]) -> String {
        guard let data = try? JSONEncoder().encode(strings) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
