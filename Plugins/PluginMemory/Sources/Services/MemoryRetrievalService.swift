import Foundation
import MemoryKit

/// 记忆检索服务。
///
/// 包装 MemoryKit 的 MemoryRetrievalService，配置从 `MemoryPlugin.config` 读取。
public actor MemoryRetrievalService {
    public static let shared = MemoryRetrievalService()

    private let service: MemoryKit.MemoryRetrievalService

    private init() {
        let config = MemoryPlugin.config
        let retrievalConfig = MemoryKit.MemoryRetrievalConfig(
            halfLifeDays: config.halfLifeDays,
            maxResults: config.maxRelevantMemories
        )
        self.service = MemoryKit.MemoryRetrievalService(
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
