import Foundation

/// `LumiChatMessage.metadata` 中图片附件的统一编解码工具。
///
/// `MessageSender` 在落库 user 消息时把 `[LumiImageAttachment]` 编码进
/// `metadata["imageAttachments"]` 的 JSON 字符串;`AgentTurnRunner` 在构造
/// `LumiLLMRequest` 时反向抽取。把这段逻辑提到 `LumiKernel` 是因为它属于
/// "消息 ↔ 附件"这一**协议层**契约,而不是 Agent runner 的实现细节。
public enum LumiImageAttachmentMetadata {
    /// 在 metadata 中图片附件的 JSON key。
    public static let key: String = "imageAttachments"

    /// 把附件列表编码进 metadata,生成一个新的字典。
    ///
    /// - 当 `attachments` 为空时,返回的字典不包含 `imageAttachments` key,
    ///   避免在历史消息里写空字符串。
    /// - 编码失败时返回的字典也不包含 `imageAttachments` key,并打印错误到 stderr
    ///   (由调用方自行选择是否记录到自己的 logger)。
    public static func encode(
        _ attachments: [LumiImageAttachment],
        into base: [String: String] = [:]
    ) -> [String: String] {
        guard !attachments.isEmpty else { return base }
        do {
            let data = try JSONEncoder().encode(attachments)
            var next = base
            next[key] = String(data: data, encoding: .utf8) ?? ""
            return next
        } catch {
            FileHandle.standardError.write(
                Data("[LumiImageAttachmentMetadata] encode failed: \(error)\n".utf8)
            )
            return base
        }
    }

    /// 从消息历史中抽取最近一条 user message 的图片附件(如有)。
    ///
    /// 多轮 agent loop 内只有最初的 user 消息可能携带附件;为安全起见,
    /// 只读取**最近**一条 user 消息的 metadata。找不到或解码失败时返回 `[]`。
    public static func extract(from history: [LumiChatMessage]) -> [LumiImageAttachment] {
        guard let lastUser = history.last(where: { $0.role == .user }),
              let json = lastUser.metadata[key],
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LumiImageAttachment].self, from: data)
        else {
            return []
        }
        return decoded
    }
}