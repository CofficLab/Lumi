import Foundation
import ProviderMessage
import os

/// HTML 卡片时间线消息的运行时桥。
///
/// 工具执行体拿不到 Kernel 容器（`SuperAgentTool.executeResult` 只有参数与
/// 执行上下文），因此插件在 `onBoot` 时把 `MessageManaging` 注入这里，
/// 工具再通过它插入时间线消息。这样工具不依赖 kernel，
/// 也避免在工具里长期持有 kernel 引用。
///
/// - Note: 这是一个**实例**而非全局单例。插件在自己的 `onBoot` 里创建它，
///   并把同一个实例注入工具；插件被禁用/卸载时随插件一起释放。
///   做成全局单例会让「多个内核并存」的场景（例如测试进程里并排跑几个
///   内核）出现互相覆盖：后启动的内核会抢走消息管理器，
///   前一个内核的工具于是把卡片插进了错误的会话。
@MainActor
public final class HTMLCanvasMessageBridge {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.html-canvas",
        category: "HTMLCanvasMessageBridge"
    )

    /// 当前生效的消息管理器。
    private var messages: (any MessageManaging)?

    public init() {}

    /// 注入消息管理器（插件 boot 时调用）。
    public func configure(messages: (any MessageManaging)?) {
        self.messages = messages
    }

    /// 清除消息管理器（插件 shutdown 时调用）。
    public func reset() {
        messages = nil
    }

    /// 插入一条 HTML 卡片时间线消息。
    ///
    /// 插入失败不应影响工具本身的执行，因此这里只记录错误。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合。
    ///   - payload: 卡片载荷。
    public func insert(
        conversationID: UUID,
        turnID: UUID?,
        payload: HTMLCanvasPayload
    ) {
        guard let messages else { return }
        let message = HTMLCanvasTimeline.message(
            conversationID: conversationID,
            turnID: turnID,
            payload: payload
        )
        messages.insertMessage(message, to: conversationID)
        Self.logger.info("inserted html canvas timeline message path=\(payload.htmlPath, privacy: .public)")
    }
}
