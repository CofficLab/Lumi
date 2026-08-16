import AgentToolKit
import KernelCore
import LocalizationKit
import LumiUI
import MarkdownKit
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import Foundation

/// 复刻自旧版 KernelLumi 的 `LumiChatMarkers`：消息正文中的特殊标记常量。
enum LumiChatMarkers {
    static let turnCompleted = "__lumi_turn_completed__"
}

/// 复刻自旧版 KernelLumi 的 `MessageTokenMetadata`：token 计数的 metadata key。
enum MessageTokenMetadata {
    static let inputKey = "inputTokens"
    static let outputKey = "outputTokens"
    static let cachedInputKey = "cachedInputTokens"
    static let cacheWriteInputKey = "cacheWriteInputTokens"
    static let cacheTotalInputKey = "cacheTotalInputTokens"
}

// MARK: - Attachments
//
// 复刻自旧版 KernelLumi 的附件类型与 metadata 编解码（渲染层所需子集）。

/// 任意文件附件（与图片附件 `LumiImageAttachment` 并行的另一条链路）。
struct LumiFileAttachment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let fileName: String
    let mimeType: String
    /// 原始文件字节（经 base64 编码）。
    let base64Data: String
    /// 文本类文件 UTF-8 解码后的正文；二进制文件为 nil。
    let textContent: String?

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        base64Data: String,
        textContent: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.textContent = textContent
    }
}

/// 图片附件。
struct LumiImageAttachment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let mimeType: String
    let base64Data: String
    let fileName: String?

    init(
        id: UUID = UUID(),
        mimeType: String,
        base64Data: String,
        fileName: String? = nil
    ) {
        self.id = id
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.fileName = fileName
    }
}

/// `Message.metadata` 中图片附件的统一编解码工具。
enum LumiImageAttachmentMetadata {
    static let key: String = "imageAttachments"

    static func decode(from metadata: [String: String]) -> [LumiImageAttachment] {
        guard let json = metadata[key],
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LumiImageAttachment].self, from: data)
        else {
            return []
        }
        return decoded
    }
}

/// `Message.metadata` 中文件附件的统一编解码工具。
enum LumiFileAttachmentMetadata {
    static let key: String = "fileAttachments"

    static func decode(from metadata: [String: String]) -> [LumiFileAttachment] {
        guard let json = metadata[key],
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LumiFileAttachment].self, from: data)
        else {
            return []
        }
        return decoded
    }
}
