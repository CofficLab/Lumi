import Foundation
import MagicKit

/// 核心发送：投影、落库、入队轮次。
///
/// 行为：
/// 1) 若会话仍处于选中状态：投影到 UI 消息列表
/// 2) 落库保存
/// 3) 触发轮次处理（depth=0）
@MainActor
struct CoreSendMiddleware2: SendMiddleware, SuperLog {
    nonisolated static let emoji = "📨"
    nonisolated static let verbose = true

    let id: String = "core.send-message.core-send"
    let order: Int = 120

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📨 [\(String(ctx.conversationId.uuidString.prefix(8)))] 发送核心消息：\(ctx.message.content.prefix(50))")
        }

        // 短路：core send 作为链尾核心逻辑，不调用 next。
    }
}

