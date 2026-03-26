import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService
    let agentSessionConfig: LLMVM
    let projectVM: ProjectVM
    
    /// RAG 服务 - 检索增强生成
    ///
    /// 提供文档索引和检索能力，让 AI 能够基于项目代码回答问题。
    ///
    /// ## 使用场景
    /// - 中间件可以调用此服务检索相关文档
    /// - 检索结果可以增强发送给 LLM 的提示词
    ///
    /// ## 示例
    /// ```swift
    /// let response = try await ctx.ragService.retrieve(query: "登录功能在哪？")
    /// for result in response.results {
    ///     print("找到: \(result.source), 相似度: \(result.score)")
    /// }
    /// ```
    let ragService: RAGService
    
    /// 仅在当前发送轮次有效的 system 提示词（不落库）
    var transientSystemPrompts: [String] = []

    /// 终止本轮发送的回调
    ///
    /// 中间件可以调用此回调来立即终止本轮发送流程。
    /// 调用后，后续的中间件和 LLM 请求都不会执行。
    var abortTurn: (() -> Void)?

    init(
        conversationId: UUID,
        message: ChatMessage,
        chatHistoryService: ChatHistoryService,
        agentSessionConfig: LLMVM,
        projectVM: ProjectVM,
        ragService: RAGService
    ) {
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
        self.agentSessionConfig = agentSessionConfig
        self.projectVM = projectVM
        self.ragService = ragService
    }

    /// 便捷方法：终止并发送系统消息
    func abort(withMessage systemMessage: ChatMessage) {
        Task {
            await chatHistoryService.saveMessageAsync(systemMessage, toConversationId: conversationId)
        }
        abortTurn?()
    }
}
