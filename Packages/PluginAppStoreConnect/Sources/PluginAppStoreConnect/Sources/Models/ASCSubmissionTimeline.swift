import Foundation
import ProviderMessage

/// 提交审核时间线消息的会话上下文。
///
/// 工具只有在拿到真实会话信息时才插入时间线消息；拿不到就不插入，
/// 避免把消息写进一个不存在的会话。
struct ASCSubmissionTimelineContext: Sendable {
    let conversationID: UUID
    let turnID: UUID?

    init(conversationID: UUID, turnID: UUID?) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}

/// 构造 App Store Connect 提交审核的时间线消息。
///
/// 这些消息只向用户解释「当前将提交什么」，不应进入后续 LLM 上下文。
/// 消息带 `renderKind = "app-store-submission"`，会被
/// `MessageTimelineEvent.isTimelineEvent` 识别并从 LLM 历史中过滤掉。
enum ASCSubmissionTimeline {
    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    static let rendererID = "com.coffic.lumi.plugin.app-store-connect.submission"

    /// 结构化载荷在 `Message.metadata` 中的键。
    static let payloadKey = "appStoreSubmissionPayload"
    /// 阶段在 `Message.metadata` 中的键。
    static let stageKey = "appStoreSubmissionStage"

    /// 构造一条提交审核时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合（可能为空，例如 ACP 链路）。
    ///   - preview: 结构化提交快照。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    static func message(
        conversationID: UUID,
        turnID: UUID?,
        preview: ASCSubmissionPreview
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .system,
            content: summaryText(for: preview),
            turnID: turnID,
            metadata: metadata(for: preview),
            renderKind: MessageTimelineEvent.appStoreSubmissionRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 生成该消息的 `metadata`，把结构化载荷 JSON 化后写入。
    static func metadata(for preview: ASCSubmissionPreview) -> [String: String] {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.appStoreSubmission,
            stageKey: preview.stage.rawValue,
        ]
        if let payload = encode(preview) {
            metadata[payloadKey] = payload
        }
        return metadata
    }

    /// 从消息 `metadata` 还原结构化载荷。
    ///
    /// 载荷缺失或损坏时返回 nil，调用方应回退到纯文本展示。
    static func decodePreview(from metadata: [String: String]) -> ASCSubmissionPreview? {
        guard let string = metadata[payloadKey],
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(ASCSubmissionPreview.self, from: data)
    }

    /// 从消息 `metadata` 读取阶段。
    static func stage(from metadata: [String: String]) -> ASCSubmissionStage? {
        guard let raw = metadata[stageKey] else { return nil }
        return ASCSubmissionStage(rawValue: raw)
    }

    /// 消息正文的可读摘要。
    ///
    /// 正文不承载完整结构化数据（那部分在 metadata 里），
    /// 只给出一个在禁用自定义渲染器时仍然可读的句子。
    static func summaryText(for preview: ASCSubmissionPreview) -> String {
        let version = preview.versionString.isEmpty ? preview.versionID : preview.versionString
        switch preview.stage {
        case .preview:
            return "即将提交审核：\(version) · \(preview.platformLabel)"
        case .submitted:
            return "已提交审核：\(version) · \(preview.platformLabel)"
        case .failed:
            return "提交审核失败：\(version) · \(preview.platformLabel)"
        }
    }

    private static func encode(_ preview: ASCSubmissionPreview) -> String? {
        guard let data = try? JSONEncoder().encode(preview) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
