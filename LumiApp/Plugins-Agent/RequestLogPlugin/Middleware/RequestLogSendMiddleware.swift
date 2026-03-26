import Foundation
import MagicKit

/// 请求日志发送中间件
///
/// 在 LLM 响应后记录完整的请求和响应数据到 SwiftData 数据库。
@MainActor
struct RequestLogSendMiddleware: SendMiddleware {
    let id: String = "request.log"
    let order: Int = 1000  // 较晚执行，确保在其他处理后记录

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
        // 记录请求数据到数据库
        await RequestLogHistoryManager.shared.add(metadata: metadata, response: response)
        
        // 同时输出到日志（便于调试）
        logToConsole(metadata: metadata, response: response)
    }

    // MARK: - 日志记录

    /// 输出到控制台
    private func logToConsole(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) {
        let timestamp = ISO8601DateFormatter().string(from: metadata.timestamp)
        
        var logLines: [String] = []
        logLines.append(String(repeating: "=", count: 60))
        logLines.append("📤 请求日志 [\(timestamp)]")
        logLines.append(String(repeating: "=", count: 60))
        
        // 请求基础信息
        logLines.append("")
        logLines.append("【请求信息】")
        logLines.append("  URL: \(metadata.url)")
        logLines.append("  请求体大小: \(metadata.formattedBodySize)")
        
        // LLM 配置
        if let config = metadata.config {
            logLines.append("")
            logLines.append("【LLM 配置】")
            logLines.append("  Provider: \(config.providerId)")
            logLines.append("  Model: \(config.model)")
        }
        
        // 响应信息
        logLines.append("")
        logLines.append("【响应信息】")
        if let error = metadata.error {
            logLines.append("  ❌ 错误: \(error.localizedDescription)")
        } else if let response = response {
            logLines.append("  ✅ 成功")
            if let latency = response.latency {
                logLines.append("  延迟: \(String(format: "%.0f", latency))ms")
            }
            if let inputTokens = response.inputTokens,
               let outputTokens = response.outputTokens {
                logLines.append("  Tokens: \(inputTokens) → \(outputTokens)")
            }
        }
        
        // 耗时
        if let duration = metadata.duration {
            logLines.append("")
            logLines.append("【耗时】\(String(format: "%.2f", duration))s")
        }
        
        logLines.append(String(repeating: "=", count: 60))
        
        print(logLines.joined(separator: "\n"))
    }
}