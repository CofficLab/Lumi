import Foundation
import ProviderMessage
import os

/// 提交审核时间线消息的运行时桥。
///
/// 工具执行体拿不到 Kernel 容器（`SuperAgentTool.execute` 只有参数），
/// 因此插件在 `onBoot` 时把 `MessageManaging` 注入这里，工具再通过它插入
/// 时间线消息。这样工具不依赖 kernel，也避免在工具里长期持有 kernel 引用。
@MainActor
enum ASCSubmissionTimelineBridge {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.app-store-connect",
        category: "ASCSubmissionTimeline"
    )

    /// 当前生效的消息管理器。
    private static var messages: (any MessageManaging)?

    /// 注入消息管理器（插件 boot 时调用）。
    static func configure(messages: (any MessageManaging)?) {
        self.messages = messages
    }

    /// 清除消息管理器（插件 shutdown 时调用）。
    static func reset() {
        messages = nil
    }

    /// 插入一条提交审核时间线消息。
    ///
    /// 插入失败不应影响提交动作本身，因此这里只记录错误。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合。
    ///   - preview: 结构化提交快照。
    static func insert(
        conversationID: UUID,
        turnID: UUID?,
        preview: ASCSubmissionPreview
    ) {
        guard let messages else { return }
        let message = ASCSubmissionTimeline.message(
            conversationID: conversationID,
            turnID: turnID,
            preview: preview
        )
        messages.insertMessage(message, to: conversationID)
        logger.info("inserted ASC submission timeline message stage=\(preview.stage.rawValue, privacy: .public)")
    }
}
