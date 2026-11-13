import Foundation
import ProviderMessage

/// 构造「子代理委托」时间线消息（#1313 Task 6）。
///
/// 这些消息只用于把一张进度卡片（工具数、耗时）呈现在聊天消息区，
/// 不应进入后续 LLM 上下文。消息带 `renderKind = "subagent-delegation"`，
/// 会被 `MessageTimelineEvent.isTimelineEvent` 识别并从 LLM 历史中过滤掉。
///
/// 消息正文给出一句可读摘要，结构化载荷放在 metadata 里——
/// 这样即使插件被禁用、渲染器不存在，正文依然能表达「派发了一个委托」。
public enum SubagentTimeline {
    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    public static let rendererID = "com.coffic.lumi.plugin.subagent.card"

    /// 结构化载荷在 `Message.metadata` 中的键。
    public static let payloadKey = "subagentCardPayload"

    /// 卡片载荷：定位委托所需的标识。
    ///
    /// 实时状态（运行中/终态、耗时、子工具数）不写进载荷——卡片视图
    /// 经 `jobID` 与 `childConversationID` 从工具管理器读取，持久化的
    /// Job 快照保证回看历史时终态依然可读。
    public struct Payload: Codable, Equatable, Sendable {
        /// 模型在 `description` 参数里给的短标签。
        public let label: String
        /// 父会话 ID：卡片据此查询 run_subagent 的 Job。
        public let parentConversationID: UUID
        /// 隐藏子会话 ID：卡片据此统计子代理的工具调用数。
        public let childConversationID: UUID
        /// 父会话里 run_subagent 的 ToolJob ID：卡片据此读状态与耗时。
        public let jobID: String
        /// 树内寻址用的稳定名字（#1328）。旧载荷没有该字段，解码为 nil，
        /// 这类历史委托不可寻址但卡片仍可正常展示。
        public let name: String?

        public init(
            label: String,
            parentConversationID: UUID,
            childConversationID: UUID,
            jobID: String,
            name: String? = nil
        ) {
            self.label = label
            self.parentConversationID = parentConversationID
            self.childConversationID = childConversationID
            self.jobID = jobID
            self.name = name
        }
    }

    /// 构造一条子代理委托卡片时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 父会话 ID。
    ///   - turnID: 所属回合（可能为空，例如 ACP 链路）。
    ///   - payload: 卡片载荷。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    public static func message(
        conversationID: UUID,
        turnID: UUID?,
        payload: Payload
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .system,
            content: summaryText(for: payload),
            turnID: turnID,
            metadata: metadata(for: payload),
            renderKind: MessageTimelineEvent.subagentDelegationRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 生成该消息的 `metadata`，把结构化载荷 JSON 化后写入。
    public static func metadata(for payload: Payload) -> [String: String] {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.subagentDelegation,
        ]
        if let encoded = encode(payload) {
            metadata[payloadKey] = encoded
        }
        return metadata
    }

    /// 从消息 `metadata` 还原结构化载荷。
    ///
    /// 载荷缺失或损坏时返回 nil，调用方应回退到纯文本展示。
    public static func decodePayload(from metadata: [String: String]) -> Payload? {
        guard let string = metadata[payloadKey],
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// 消息正文的可读摘要：渲染器缺席时仍然可读。
    public static func summaryText(for payload: Payload) -> String {
        "Subagent delegation: \(payload.label)"
    }

    private static func encode(_ payload: Payload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}