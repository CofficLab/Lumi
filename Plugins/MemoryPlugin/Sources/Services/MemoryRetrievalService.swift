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
}
