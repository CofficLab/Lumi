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
        _ = response
        // 记录请求数据到数据库
        await RequestLogHistoryManager.shared.add(metadata: metadata)
        
        // 同时输出到日志（便于调试）
        logToConsole(metadata: metadata)
    }

    // MARK: - 日志记录

    /// 输出到控制台
    private func logToConsole(
        metadata: RequestMetadata
    ) {
        let timestamp = ISO8601DateFormatter().string(from: metadata.sentAt)
        
        var logLines: [String] = []
        logLines.append(String(repeating: "=", count: 60))
        logLines.append("📤 请求日志 [\(timestamp)]")
        logLines.append(String(repeating: "=", count: 60))
        
        // 请求基础信息
        logLines.append("")
        logLines.append("【请求信息】")
        logLines.append("  Method: \(metadata.method)")
        logLines.append("  URL: \(metadata.url)")
        logLines.append("  请求体大小: \(metadata.formattedBodySize)")
        if !metadata.requestHeaders.isEmpty {
            logLines.append("  Headers: \(metadata.requestHeaders)")
        }
        
        // 响应信息
        logLines.append("")
        logLines.append("【响应信息】")
        if let error = metadata.error {
            logLines.append("  ❌ 错误: \(error.localizedDescription)")
        } else {
            logLines.append("  ✅ 成功")
            if let statusCode = metadata.responseStatusCode {
                logLines.append("  HTTP Status: \(statusCode)")
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
