import Foundation
import MagicKit
import os

/// 请求日志发送中间件
///
/// 在 LLM 响应后记录完整的请求和响应数据。
@MainActor
struct RequestLogSendMiddleware: SendMiddleware {
    let id: String = "request.log"
    let order: Int = 1000  // 较晚执行，确保在其他处理后记录

    /// 日志记录器
    private let logger = Logger(subsystem: "RequestLog", category: "middleware")

    // MARK: - SendMiddleware

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 发送前不做处理，直接继续
        await next(ctx)
    }

    func handlePost(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async {
        // 记录请求数据
        await logRequestData(metadata: metadata, response: response)
    }

    // MARK: - 日志记录

    /// 记录请求数据
    private func logRequestData(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async {
        let timestamp = ISO8601DateFormatter().string(from: metadata.timestamp)
        
        // 构建日志内容
        var logLines: [String] = []
        logLines.append(String(repeating: "=", count: 60))
        logLines.append("📤 请求日志 [\(timestamp)]")
        logLines.append(String(repeating: "=", count: 60))
        
        // 请求基础信息
        logLines.append("")
        logLines.append("【请求信息】")
        logLines.append("  URL: \(metadata.url)")
        logLines.append("  请求体大小: \(metadata.formattedBodySize)")
        logLines.append("  时间戳: \(timestamp)")
        
        // LLM 配置
        if let config = metadata.config {
            logLines.append("")
            logLines.append("【LLM 配置】")
            logLines.append("  Provider: \(config.providerId)")
            logLines.append("  Model: \(config.model)")
            logLines.append("  Temperature: \(config.temperature ?? 0)")
            logLines.append("  Max Tokens: \(config.maxTokens ?? 0)")
        }
        
        // 消息列表
        if let messages = metadata.messages {
            logLines.append("")
            logLines.append("【消息列表】(\(messages.count) 条)")
            for (index, message) in messages.enumerated() {
                let contentPreview = String(message.content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
                logLines.append("  [\(index)] \(message.role.rawValue): \(contentPreview)")
                if message.hasToolCalls {
                    let toolNames = message.toolCalls?.map(\.name).joined(separator: ", ") ?? ""
                    logLines.append("       🔧 工具调用: \(toolNames)")
                }
            }
        }
        
        // 工具列表
        if let tools = metadata.tools, !tools.isEmpty {
            logLines.append("")
            logLines.append("【可用工具】(\(tools.count) 个)")
            for tool in tools.prefix(5) {
                let descPreview = String(tool.description.prefix(50)).replacingOccurrences(of: "\n", with: " ")
                logLines.append("  - \(tool.name): \(descPreview)")
            }
            if tools.count > 5 {
                logLines.append("  ... 还有 \(tools.count - 5) 个工具")
            }
        }
        
        // 临时系统提示词
        if let prompts = metadata.transientPrompts, !prompts.isEmpty {
            logLines.append("")
            logLines.append("【临时系统提示词】(\(prompts.count) 条)")
            for (index, prompt) in prompts.enumerated() {
                let promptPreview = String(prompt.prefix(100)).replacingOccurrences(of: "\n", with: " ")
                logLines.append("  [\(index)]: \(promptPreview)")
            }
        }
        
        // 响应信息
        logLines.append("")
        logLines.append("【响应信息】")
        if let error = metadata.error {
            logLines.append("  ❌ 错误: \(error.localizedDescription)")
        } else if let response = response {
            logLines.append("  ✅ 成功")
            let contentPreview = String(response.content.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            logLines.append("  内容: \(contentPreview)")
            if response.hasToolCalls {
                let toolNames = response.toolCalls?.map(\.name).joined(separator: ", ") ?? ""
                logLines.append("  🔧 工具调用: \(toolNames)")
            }
            if let latency = response.latency {
                logLines.append("  延迟: \(String(format: "%.0f", latency))ms")
            }
            if let inputTokens = response.inputTokens {
                logLines.append("  输入 Token: \(inputTokens)")
            }
            if let outputTokens = response.outputTokens {
                logLines.append("  输出 Token: \(outputTokens)")
            }
            if let totalTokens = response.totalTokens {
                logLines.append("  总 Token: \(totalTokens)")
            }
            if let finishReason = response.finishReason {
                logLines.append("  完成原因: \(finishReason)")
            }
        } else {
            logLines.append("  ⚠️ 无响应")
        }
        
        // Token 使用统计
        if let tokenUsage = metadata.tokenUsage {
            logLines.append("")
            logLines.append("【Token 使用】")
            logLines.append("  Prompt Tokens: \(tokenUsage.promptTokens)")
            logLines.append("  Completion Tokens: \(tokenUsage.completionTokens)")
            logLines.append("  Total Tokens: \(tokenUsage.totalTokens)")
        }
        
        // 耗时
        if let duration = metadata.duration {
            logLines.append("")
            logLines.append("【耗时】")
            logLines.append("  总耗时: \(String(format: "%.2f", duration))s")
        }
        
        logLines.append("")
        logLines.append(String(repeating: "=", count: 60))
        
        // 输出日志
        let logContent = logLines.joined(separator: "\n")
        logger.info("\n\(logContent)")
        
        // 同时输出到控制台（便于调试）
        print(logContent)
    }
}