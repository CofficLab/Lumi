import Foundation
import MagicKit
import SwiftData

/// 聊天历史服务 - 使用 SwiftData 存储对话
///
/// ## 线程安全
///
/// 整个服务标记为 `@MainActor`，所有数据库操作都在主线程执行，
/// 消除 `Unbinding from the main queue` 警告和跨线程竞态。
@MainActor
final class ChatHistoryService: SuperLog, Sendable {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let llmService: LLMService

    /// 使用 LLM 服务和模型容器初始化
    init(llmService: LLMService, modelContainer: ModelContainer, reason: String) {
        self.llmService = llmService
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 聊天存储已初始化")
        }
    }

    /// 获取模型上下文
    internal func getContext() -> ModelContext {
        return modelContext
    }

    // MARK: - 工具方法

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }
}
