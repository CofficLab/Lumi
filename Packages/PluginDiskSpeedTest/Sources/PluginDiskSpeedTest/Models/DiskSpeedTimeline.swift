import Foundation
import ProviderMessage

/// 构造「磁盘测速卡片」时间线消息。
///
/// 这些消息只用于把测速进度呈现在聊天消息区，不应进入后续 LLM 上下文。
/// 消息带 `renderKind = "disk-speed"`，会被 `MessageTimelineEvent.isTimelineEvent`
/// 识别并从 LLM 历史中过滤掉。
///
/// ## 载荷为什么放在 content
///
/// 与 Finder / HTMLCanvas 不同，本插件把结构化载荷放在 `Message.content`
/// 而不是 `Message.metadata`。原因是状态推进：
/// 测速卡片必须能从「正在测试」更新为「已完成，读 1.2 GB/s」，
/// 而 `MessageManaging.updateMessage(id:in:content:)` **只能改 content**，
/// 改不了已经落库的 metadata。载荷若放在 metadata，卡片将永远停在初始状态。
///
/// metadata 因此只保留时间线标记（供 `isTimelineEvent` 过滤与渲染器定位）。
enum DiskSpeedTimeline {

    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    static let rendererID = "com.coffic.lumi.plugin.disk-speed-test.card"

    /// 构造一条磁盘测速时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合（可能为空，例如 ACP 链路）。
    ///   - payload: 测速载荷。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    static func message(
        conversationID: UUID,
        turnID: UUID?,
        payload: DiskSpeedPayload
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .system,
            content: encode(payload) ?? summaryText(for: payload),
            turnID: turnID,
            metadata: [MessageTimelineEvent.metadataKey: MessageTimelineEvent.diskSpeed],
            renderKind: MessageTimelineEvent.diskSpeedRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 把载荷编码成 `Message.content` 的字符串。
    ///
    /// 使用 JSON 编码以保证数值精度与可解析性；编码失败时返回 nil，
    /// 由调用方回退到可读摘要。
    static func encode(_ payload: DiskSpeedPayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从消息 `content` 还原结构化载荷。
    ///
    /// 载荷缺失或损坏时返回 nil，渲染器应回退到纯文本展示。
    static func decodePayload(from content: String) -> DiskSpeedPayload? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DiskSpeedPayload.self, from: data)
    }

    /// 消息正文的可读摘要。
    ///
    /// 只在 JSON 编码失败时使用，确保渲染器缺席时用户仍能看懂这条消息。
    static func summaryText(for payload: DiskSpeedPayload) -> String {
        switch payload.phase {
        case .running:
            return "Testing disk speed..."
        case .failed:
            let reason = payload.failureReason ?? "unknown error"
            return "Disk speed test failed: \(reason)"
        case .finished:
            let read = payload.displayReadSpeed ?? "n/a"
            let write = payload.displayWriteSpeed ?? "n/a"
            return "Disk speed: read \(read), write \(write)"
        }
    }
}
