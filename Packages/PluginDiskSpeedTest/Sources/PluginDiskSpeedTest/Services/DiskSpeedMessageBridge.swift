import Foundation
import ProviderMessage
import os

/// 磁盘测速卡片时间线消息的运行时桥。
///
/// 工具执行体拿不到 Kernel 容器（`SuperAgentTool.executeResult` 只有参数与
/// 执行上下文），因此插件在 `onBoot` 时把 `MessageManaging` 注入这里，
/// 工具再通过它插入与更新时间线消息。这样工具不依赖 kernel，
/// 也避免在工具里长期持有 kernel 引用。
///
/// - Note: 这是一个**实例**而非全局单例。插件在自己的 `onBoot` 里创建它，
///   并把同一个实例注入工具；插件被禁用/卸载时随插件一起释放。
///   做成全局单例会让「多个内核并存」的场景（例如测试进程里并排跑几个
///   内核）出现互相覆盖：后启动的内核会抢走消息管理器，
///   前一个内核的工具于是把卡片插进了错误的会话。
@MainActor
public final class DiskSpeedMessageBridge {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.disk-speed-test",
        category: "DiskSpeedMessageBridge"
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

    /// 插入一条磁盘测速时间线消息，返回该消息的 ID。
    ///
    /// 插入失败不应影响工具本身的执行，因此这里只记录错误并返回 nil。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合。
    ///   - payload: 测速载荷。
    /// - Returns: 插入的消息 ID；失败时为 nil。
    @discardableResult
    public func insert(
        conversationID: UUID,
        turnID: UUID?,
        payload: DiskSpeedPayload
    ) -> UUID? {
        guard let messages else { return nil }
        let message = DiskSpeedTimeline.message(
            conversationID: conversationID,
            turnID: turnID,
            payload: payload
        )
        messages.insertMessage(message, to: conversationID)
        Self.logger.info("inserted disk speed card message phase=\(payload.phase.rawValue, privacy: .public)")
        return message.id
    }

    /// 更新已插入的测速卡片，把载荷推进到新状态。
    ///
    /// 更新只改 `content`（唯一可写的载荷通道），因此载荷必须序列化进 content。
    /// 消息不存在时静默忽略——卡片可能已被用户删除。
    ///
    /// - Parameters:
    ///   - messageID: 卡片消息 ID。
    ///   - conversationID: 所属会话。
    ///   - payload: 新的测速载荷。
    public func update(
        messageID: UUID,
        conversationID: UUID,
        payload: DiskSpeedPayload
    ) {
        guard let messages else { return }
        guard let content = DiskSpeedTimeline.encode(payload) else { return }
        messages.updateMessage(id: messageID, in: conversationID, content: content)
        Self.logger.info("updated disk speed card message phase=\(payload.phase.rawValue, privacy: .public)")
    }
}
