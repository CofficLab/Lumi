import Foundation
import LumiCoreKit
import HttpKit

/// 请求日志发送中间件
///
/// 在 LLM 响应后记录完整的请求和响应数据到 SwiftData 数据库。
@MainActor
public struct RequestLogSuperSendMiddleware: SuperSendMiddleware {
    public let id: String = "request.log"
    public let order: Int = 1000  // 较晚执行，确保在其他处理后记录

    // MARK: - SuperSendMiddleware

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 发送前不做处理，直接继续
        await next(ctx)
    }

    public func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        var mutableMetadata = metadata

        // 从响应中提取响应体内容
        if let response {
            let content = response.content
            mutableMetadata.responseBodySizeBytes = content.utf8.count

            // 截断到 2000 字符作为预览
            let previewLimit = 2000
            if content.utf8.count > previewLimit {
                let truncated = String(content.prefix(previewLimit))
                mutableMetadata.responseBodyPreview = truncated + "…"
            } else {
                mutableMetadata.responseBodyPreview = content
            }

            // 错误详情也记录
            if let rawError = response.rawErrorDetail, !rawError.isEmpty {
                mutableMetadata.responseBodyPreview = (mutableMetadata.responseBodyPreview ?? "") + "\n--- Error Detail ---\n" + rawError
            }
        }

        await RequestLogHistoryManager.shared.add(metadata: mutableMetadata)
    }
}
