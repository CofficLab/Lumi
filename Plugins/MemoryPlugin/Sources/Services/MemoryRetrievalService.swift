import Foundation

/// 记忆检索服务。
///
/// 包装 MemoryKit 的 MemoryFileRetrievalService，配置从 `MemoryPlugin.config` 读取。
public actor MemoryRetrievalService {
    public static let shared = MemoryRetrievalService()

    private let service: MemoryFileRetrieval

    /// 检索结果缓存。AgentTurnRunner 每个 LLM 迭代(含工具回合后的每一轮)都会调
    /// `findRelevant`,但同一 turn 内 query(最后一条 user 消息)和 projectPath 都不变,
    /// 记忆文件也只在 turn 结束后(`onTurnFinished`)才写入。故结果可安全缓存。
    /// TTL 设 30s:覆盖一个 turn 的典型时长,同时保证记忆变更后不会长时间过期。
    private var cache: [CacheKey: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 30

    private struct CacheKey: Hashable {
        let query: String
        let projectPath: String?
        let maxResults: Int
        let injectGlobal: Bool
        let injectProject: Bool
    }

    private struct CacheEntry {
        let results: [MemoryItem]
        let timestamp: Date
    }

    private init() {
        let config = MemoryPlugin.config
        let retrievalConfig = MemoryFileRetrievalConfig(
            halfLifeDays: config.halfLifeDays,
            maxResults: config.maxRelevantMemories
        )
        self.service = MemoryFileRetrieval(
            config: retrievalConfig,
            verbose: MemoryPlugin.verbose
        )
    }

    /// 检索与查询相关的记忆
    public func findRelevant(
        query: String,
        scope: MemoryScope,
        maxResults: Int = 3
    ) async -> [MemoryItem] {
        let storage = await MemoryStorageService.shared.memoryKitStorage
        return await service.findRelevant(
            query: query,
            scope: scope,
            storage: storage,
            maxResults: maxResults
        )
    }

    /// 在全局和当前项目作用域中联合检索，并按 ID 去重。
    ///
    /// 结果按 (query, projectPath, maxResults, 注入开关) 缓存(TTL 30s),
    /// 因为同一 turn 内这些输入全部不变。调用方(MemoryContextService)已在末尾非
    /// user 消息时提前返回,但首轮检索的结果会被后续轮次命中,避免重复文件 IO。
    public func findRelevant(
        query: String,
        projectPath: String?,
        maxResults: Int
    ) async -> [MemoryItem] {
        let limit = max(0, maxResults)
        guard limit > 0 else { return [] }

        let key = CacheKey(
            query: query,
            projectPath: projectPath,
            maxResults: limit,
            injectGlobal: MemoryPlugin.config.injectGlobalIndex,
            injectProject: MemoryPlugin.config.injectProjectIndex
        )
        if let entry = cache[key], Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.results
        }

        var results: [MemoryItem] = []
        if MemoryPlugin.config.injectGlobalIndex {
            results += await findRelevant(query: query, scope: .global, maxResults: limit)
        }
        if MemoryPlugin.config.injectProjectIndex,
           let projectPath,
           !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results += await findRelevant(query: query, scope: .project(projectPath), maxResults: limit)
        }

        var seen = Set<String>()
        let deduped = results
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt { return lhs.id < rhs.id }
                return lhs.updatedAt > rhs.updatedAt
            }
            .filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
            .prefix(limit)
            .map { $0 }

        cache[key] = CacheEntry(results: deduped, timestamp: Date())
        return deduped
    }

    /// 清除检索缓存。在记忆写入后调用,确保下次检索读到最新数据。
    public func invalidateCache() {
        cache.removeAll()
    }
}
