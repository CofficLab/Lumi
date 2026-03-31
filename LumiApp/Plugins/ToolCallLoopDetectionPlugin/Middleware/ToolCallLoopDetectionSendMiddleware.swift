import Foundation
import MagicKit

/// 工具调用循环检测发送中间件
///
/// 通过分析历史消息中的工具调用模式，检测是否进入无限循环。
/// 如果检测到循环，将终止本轮发送并向用户显示警告。
@MainActor
struct ToolCallLoopDetectionSendMiddleware: SendMiddleware {
    let id: String = "tool-call-loop-detection"
    let order: Int = 100  // 较晚执行，在其他预处理之后

    // MARK: - 执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 1. 分析历史工具调用
        if let loopPattern = await detectToolLoopPattern(in: ctx) {
            // 2. 检测到循环，终止本轮
            await handleDetectedLoop(loopPattern, context: ctx)
            return  // 不调用 next(ctx)，终止后续流程
        }

        // 3. 未检测到循环，继续执行
        await next(ctx)
    }

    // MARK: - 检测逻辑

    /// 检测工具调用循环模式
    ///
    /// - Parameter ctx: 发送上下文
    /// - Returns: 如果检测到循环，返回循环信息；否则返回 nil
    private func detectToolLoopPattern(
        in ctx: SendMessageContext
    ) async -> ToolLoopPattern? {
        // 加载最近的消息（通过上下文提供的服务）
        guard let messages = await ctx.chatHistoryService.loadMessages(
            forConversationId: ctx.conversationId
        ) else {
            return nil
        }

        // 提取最近的工具调用（限制数量以避免性能问题）
        let recentMessages = Array(messages.suffix(100))

        // 统计工具调用签名 {签名ID: 调用次数}
        var signatureCounts: [String: Int] = [:]
        // 保存签名详情 {签名ID: 签名信息}
        var signatureDetails: [String: ToolCallSignatureInfo] = [:]

        for message in recentMessages {
            guard message.role == .tool,
                  let toolCallID = message.toolCallID,
                  let assistantMessage = findAssistantMessage(for: toolCallID, in: recentMessages),
                  let toolCalls = assistantMessage.toolCalls,
                  let toolCall = toolCalls.first(where: { $0.id == toolCallID }) else {
                continue
            }

            let signatureId = "\(toolCall.name):\(toolCall.arguments)"

            // 统计次数
            signatureCounts[signatureId, default: 0] += 1

            // 保存详情（只保存一次）
            if signatureDetails[signatureId] == nil {
                signatureDetails[signatureId] = ToolCallSignatureInfo(
                    name: toolCall.name,
                    arguments: toolCall.arguments
                )
            }
        }

        // 检测循环
        for (signatureId, count) in signatureCounts {
            if count >= AgentConfig.repeatedToolWindowThreshold,
               let info = signatureDetails[signatureId] {
                return ToolLoopPattern(
                    toolName: info.name,
                    toolArguments: info.arguments,
                    count: count,
                    threshold: AgentConfig.repeatedToolWindowThreshold
                )
            }
        }

        return nil
    }

    /// 根据工具调用 ID 查找对应的 assistant 消息
    private func findAssistantMessage(
        for toolCallID: String,
        in messages: [ChatMessage]
    ) -> ChatMessage? {
        for message in messages.reversed() {
            if message.role == .assistant,
               let toolCalls = message.toolCalls,
               toolCalls.contains(where: { $0.id == toolCallID }) {
                return message
            }
        }
        return nil
    }

    /// 处理检测到的循环
    private func handleDetectedLoop(
        _ pattern: ToolLoopPattern,
        context: SendMessageContext
    ) async {
        AppLogger.core.warning("""
        [ToolCallLoopDetection] 检测到工具调用循环：
        - 工具：\(pattern.toolName)
        - 调用次数：\(pattern.count)
        - 阈值：\(pattern.threshold)
        - 参数：\(pattern.toolArguments.max(100))
        """)

        // 从上下文获取语言偏好
        let config = context.projectVM
        let languagePreference = config.languagePreference

        // 生成循环警告消息
        let loopMessage = ChatMessage.repeatedToolLoopMessage(
            languagePreference: languagePreference,
            tool: ToolCall(
                id: "detected",
                name: pattern.toolName,
                arguments: pattern.toolArguments
            ),
            repeatedCount: pattern.count,
            windowCount: pattern.count,
            conversationId: context.conversationId
        )

        // 终止本轮（通过上下文提供的终止能力）
        context.abort(withMessage: loopMessage)
    }
}

// MARK: - 数据结构

/// 工具调用签名信息
private struct ToolCallSignatureInfo {
    let name: String
    let arguments: String
}

/// 工具调用循环模式
private struct ToolLoopPattern {
    let toolName: String
    let toolArguments: String
    let count: Int
    let threshold: Int
}
