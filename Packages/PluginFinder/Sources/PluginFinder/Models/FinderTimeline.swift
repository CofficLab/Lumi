import Foundation
import ProviderMessage

/// 构造「Finder 卡片」时间线消息。
///
/// 这些消息只用于把一个可交互卡片呈现在聊天消息区，
/// 不应进入后续 LLM 上下文。消息带 `renderKind = "finder-card"`，
/// 会被 `MessageTimelineEvent.isTimelineEvent` 识别并从 LLM 历史中过滤掉。
///
/// 消息正文给出一句可读摘要，结构化载荷放在 metadata 里——
/// 这样即使插件被禁用、渲染器不存在，正文依然能表达「有个文件夹可以打开」。
enum FinderTimeline {
    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    static let rendererID = "com.coffic.lumi.plugin.finder.card"

    /// 结构化载荷在 `Message.metadata` 中的键。
    static let payloadKey = "finderCardPayload"

    /// 构造一条 Finder 卡片时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合（可能为空，例如 ACP 链路）。
    ///   - payload: 卡片载荷。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    static func message(
        conversationID: UUID,
        turnID: UUID?,
        payload: FinderCardPayload
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .system,
            content: summaryText(for: payload),
            turnID: turnID,
            metadata: metadata(for: payload),
            renderKind: MessageTimelineEvent.finderRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 生成该消息的 `metadata`，把结构化载荷 JSON 化后写入。
    static func metadata(for payload: FinderCardPayload) -> [String: String] {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.finder,
        ]
        if let encoded = encode(payload) {
            metadata[payloadKey] = encoded
        }
        return metadata
    }

    /// 从消息 `metadata` 还原结构化载荷。
    ///
    /// 载荷缺失或损坏时返回 nil，调用方应回退到纯文本展示。
    static func decodePayload(from metadata: [String: String]) -> FinderCardPayload? {
        guard let string = metadata[payloadKey],
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(FinderCardPayload.self, from: data)
    }

    /// 消息正文的可读摘要。
    ///
    /// 正文不承载完整结构化数据（那部分在 metadata 里），
    /// 只给出一个在 Finder 渲染器缺席时仍然可读的句子。
    static func summaryText(for payload: FinderCardPayload) -> String {
        "\(payload.displayTitle)：\(payload.path)"
    }

    private static func encode(_ payload: FinderCardPayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
