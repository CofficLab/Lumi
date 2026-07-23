import Foundation

/// `LumiChatMessage.metadata` 中**文件**附件的统一编解码工具(与 `LumiImageAttachmentMetadata`
/// 平行的一条链路)。
///
/// `MessageSender` 在落库 user 消息时把 `[LumiFileAttachment]` 编码进
/// `metadata["fileAttachments"]` 的 JSON 字符串;`AgentTurnRunner` 在构造
/// `LumiLLMRequest` 时反向抽取。把这段逻辑提到 `LumiKernel` 是因为它属于
/// "消息 ↔ 附件"这一**协议层**契约,而不是某个插件的实现细节。
public enum LumiFileAttachmentMetadata {
    /// 在 metadata 中文件附件的 JSON key。
    public static let key: String = "fileAttachments"

    /// 把文件附件列表编码进 metadata,生成一个新的字典。
    ///
    /// - 当 `attachments` 为空时,返回的字典不包含 `fileAttachments` key,
    ///   避免在历史消息里写空字符串。
    /// - 编码失败时返回的字典也不包含 `fileAttachments` key,并打印错误到 stderr。
    public static func encode(
        _ attachments: [LumiFileAttachment],
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
                Data("[LumiFileAttachmentMetadata] encode failed: \(error)\n".utf8)
            )
            return base
        }
    }

    /// 从单条消息的 metadata 中解码文件附件。
    ///
    /// 与 `extract(from:)`(从历史取最近一条 user)不同,这个方法直接解码传入的
    /// metadata 字典,供消息渲染层针对**单条**消息(任意 role)展示附件。
    /// 找不到 key 或解码失败时返回 `[]`。
    public static func decode(from metadata: [String: String]) -> [LumiFileAttachment] {
        guard let json = metadata[key],
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LumiFileAttachment].self, from: data)
        else {
            return []
        }
        return decoded
    }

    /// 从消息历史中抽取最近一条 user message 的文件附件(如有)。
    ///
    /// 多轮 agent loop 内只有最初的 user 消息可能携带附件;为安全起见,
    /// 只读取**最近**一条 user 消息的 metadata。找不到或解码失败时返回 `[]`。
    public static func extract(from history: [LumiChatMessage]) -> [LumiFileAttachment] {
        guard let lastUser = history.last(where: { $0.role == .user }) else {
            return []
        }
        return decode(from: lastUser.metadata)
    }
}
