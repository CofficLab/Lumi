import Foundation

/// 记忆检索服务。
///
/// 包装 MemoryKit 的 MemoryRetrievalService，配置从 `MemoryPlugin.config` 读取。
public actor MemoryRetrievalService {
    public static let shared = MemoryRetrievalService()

    private let service: MemoryFileRetrieval

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
    public func findRelevant(
        query: String,
        projectPath: String?,
        maxResults: Int
    ) async -> [MemoryItem] {
        let limit = max(0, maxResults)
        guard limit > 0 else { return [] }

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
        return results
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt { return lhs.id < rhs.id }
                return lhs.updatedAt > rhs.updatedAt
            }
            .filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
            .prefix(limit)
            .map { $0 }
    }
}
