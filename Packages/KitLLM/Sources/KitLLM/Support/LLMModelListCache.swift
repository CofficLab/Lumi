import Foundation

/// LLM 供应商远程模型列表的本地缓存。
///
/// 双层缓存：
/// - 内存缓存：本次会话内多次读取直接命中，避免重复请求。
/// - 磁盘缓存（UserDefaults）：跨启动保留，启动优先展示缓存再后台刷新。
///
/// 约定：**失败 / 过期不删除旧值**，仅在成功拉取后调用 `store` 更新。
/// `isStale` 以数据同步时间（`syncedAt`）为准——超过 TTL 表示"该重新拉取了"，
/// 但旧值仍可用（供离线/失败时兜底）。
public final class LLMModelListCache: @unchecked Sendable {
    private struct Snapshot: Codable {
        var models: [CachedModel]
        var syncedAt: Date
    }

    private struct CachedModel: Codable {
        let id: String
        let displayName: String?
        let contextWindowSize: Int?
    }

    /// 数据新鲜度阈值（TTL），默认 24h。
    public static let ttl: TimeInterval = 24 * 60 * 60

    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private let cacheKey: String
    private var memory: Snapshot?

    /// - Parameters:
    ///   - providerID: 供应商 id（用于隔离不同供应商的缓存键）。
    ///   - userDefaults: 磁盘缓存载体，默认 `.standard`。
    public init(providerID: String, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cacheKey = "com.kit.llm.remoteModelList.\(providerID)"
    }

    /// 读取缓存快照；磁盘未命中或磁盘内容损坏时返回 `nil`。
    ///
    /// 返回的 `models` 为复制值，避免外部改标签污染缓存。
    public func cachedSnapshot() -> (models: [LLMModelInfo], syncedAt: Date, isStale: Bool)? {
        lock.lock(); defer { lock.unlock() }
        let snapshot: Snapshot
        if let memory {
            snapshot = memory
        } else if let disk = readDisk() {
            snapshot = disk
            memory = disk
        } else {
            return nil
        }
        return (
            models: snapshot.models.map { LLMModelInfo(id: $0.id, displayName: $0.displayName, contextWindowSize: $0.contextWindowSize) },
            syncedAt: snapshot.syncedAt,
            isStale: Date().timeIntervalSince(snapshot.syncedAt) > Self.ttl
        )
    }

    /// 成功拉取后写入缓存（内存 + 磁盘）。`models` 为空时忽略写入。
    public func store(models: [LLMModelInfo], syncedAt: Date = Date()) {
        guard !models.isEmpty else { return }
        let snapshot = Snapshot(
            models: models.map { CachedModel(id: $0.id, displayName: $0.displayName, contextWindowSize: $0.contextWindowSize) },
            syncedAt: syncedAt
        )
        lock.lock(); defer { lock.unlock() }
        memory = snapshot
        writeDisk(snapshot)
    }

    /// 清空缓存（内存 + 磁盘）。
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        memory = nil
        userDefaults.removeObject(forKey: cacheKey)
    }

    // MARK: - Private

    private func readDisk() -> Snapshot? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func writeDisk(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }
}