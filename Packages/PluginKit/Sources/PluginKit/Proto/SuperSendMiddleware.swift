import Foundation
import HttpKit

/// 消息发送中间件协议
///
/// 中间件可以在两个阶段介入：
/// 1. **发送前** (`handle`): 修改或增强发送给 LLM 的消息
/// 2. **发送后** (`handlePost`): 记录日志、审计、分析响应
@MainActor
public protocol SuperSendMiddleware {
    /// 中间件唯一标识
    var id: String { get }
    /// 执行顺序（数字越小越先执行）
    var order: Int { get }

    /// 发送前处理
    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async

    /// 发送后处理（可选实现）
    func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async
}

/// 默认实现：发送后处理为空操作
extension SuperSendMiddleware {
    public func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        // 默认不执行任何操作
    }
}
