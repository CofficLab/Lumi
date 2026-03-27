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
    }
}
