import Foundation
import KitMail

/// 单次同步结果统计。
public struct MailSyncStats: Sendable, Equatable {
    public var inserted = 0
    public var updated = 0
    public var removed = 0

    public init(inserted: Int = 0, updated: Int = 0, removed: Int = 0) {
        self.inserted = inserted
        self.updated = updated
        self.removed = removed
    }
}

/// 邮件增量同步服务（actor）。
///
/// 对每个文件夹：以缓存最大 UID 为游标增量拉取 → upsert 摘要；
/// `fullSync` 模式拉全部并清理远端已不存在的本地条目。
/// 未读/星标变化随摘要一并覆盖（`fullSync` 时才可靠收敛）。
public actor MailSyncService {
    private let session: any MailSessionServing
    private let cache: MailCacheService

    public init(session: any MailSessionServing, cache: MailCacheService) {
        self.session = session
        self.cache = cache
    }

    /// 增量同步单个文件夹。
    public func syncFolder(
        _ folder: String,
        accountID: UUID,
        limit: Int = 50,
        fullSync: Bool = false
    ) async throws -> MailSyncStats {
        let cursor = fullSync ? nil : (try await cache.lastUID(accountID: accountID, folder: folder))
        let summaries = try await session.fetchMessages(
            folder: folder,
            sinceUID: cursor,
            limit: limit
        )

        var stats = MailSyncStats()
        for summary in summaries {
            if try await cache.contains(accountID: accountID, folder: folder, uid: summary.uid) {
                stats.updated += 1
            } else {
                stats.inserted += 1
            }
        }
        try await cache.upsertMessages(summaries, accountID: accountID, folder: folder)

        // 远端已删除清理：仅在全量同步或增量能确定"完整集合"时执行。
        // 增量模式下远端集合 = 游标后的新增，不删旧 uid；全量模式下远端集合即全部。
        if fullSync {
            let remoteUIDs = Set(summaries.map(\.uid))
            let removed = try await cache.removeMessages(
                accountID: accountID,
                folder: folder,
                keeping: remoteUIDs
            )
            stats.removed = removed
        }
        return stats
    }

    /// 同步多个文件夹（文件夹树刷新时批量调用）。
    public func syncFolders(
        _ folders: [String],
        accountID: UUID,
        limit: Int = 50,
        fullSync: Bool = false
    ) async throws -> [String: MailSyncStats] {
        var result: [String: MailSyncStats] = [:]
        for folder in folders {
            result[folder] = try await syncFolder(
                folder,
                accountID: accountID,
                limit: limit,
                fullSync: fullSync
            )
        }
        return result
    }
}
