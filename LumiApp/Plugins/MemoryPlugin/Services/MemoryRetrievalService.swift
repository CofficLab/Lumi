import Foundation
import MemoryKit

/// App 层记忆检索服务适配器
///
/// 内部委托给 MemoryKit 的 MemoryRetrievalService，
/// 配置从 MemoryPluginLocalStore 读取。
actor MemoryRetrievalService {
    static let shared = MemoryRetrievalService()

    private let service: MemoryKit.MemoryRetrievalService

    private init() {
        let config = MemoryKit.MemoryRetrievalConfig(
            halfLifeDays: MemoryPluginLocalStore.shared.halfLifeDays,
            maxResults: MemoryPluginLocalStore.shared.maxRelevantMemories
        )
        self.service = MemoryKit.MemoryRetrievalService(
            config: config,
            verbose: MemoryPluginLocalStore.shared.isVerbose
        )
    }

    // MARK: - 委托 API（与 App 层现有调用签名一致）

    /// 检索与查询相关的记忆
    func findRelevant(
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
