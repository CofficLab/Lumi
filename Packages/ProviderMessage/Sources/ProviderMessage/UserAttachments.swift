import Foundation
import UniformTypeIdentifiers

// MARK: - User attachments（发送挂起池 + 消息 metadata）

/// 用户随消息一起发送的图片附件（挂起池与持久化均使用本类型）。
///
/// 复刻旧版 `LumiImageAttachment`：`base64Data` 承载图片内容，
/// 落库时经 `UserAttachmentMetadata` 序列化进 `Message.metadata["imageAttachments"]`。
public struct UserImageAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let mimeType: String
    public let base64Data: String
    public let fileName: String?

    public init(
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

/// 用户随消息一起发送的文件附件（与图片并行的链路）。
///
/// 文本类附件提供 `textContent`（正文在 AgentLoop 注入用户消息文本），
/// 二进制附件提供 `base64Data`；二者至少其一。
public struct UserFileAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let mimeType: String
    public let base64Data: String?
    public let textContent: String?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        base64Data: String? = nil,
        textContent: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.textContent = textContent
    }
}

/// 将本地文件转换为可随用户消息发送的附件。
///
/// 附件同时保留原始字节和可识别的 UTF-8 文本：前者保证二进制文件可传递，
/// 后者便于文本文件被模型直接理解。文件路径只用于读取，不会写入消息正文。
public enum UserFileAttachmentLoader {
    public static func load(from url: URL) throws -> UserFileAttachment {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let mimeType = UTType(filenameExtension: url.pathExtension.lowercased())?.preferredMIMEType
            ?? "application/octet-stream"

        return UserFileAttachment(
            fileName: url.lastPathComponent,
            mimeType: mimeType,
            base64Data: data.base64EncodedString(),
            textContent: String(data: data, encoding: .utf8)
        )
    }
}

// MARK: - Metadata codec

/// `Message.metadata` 中附件 JSON 的编解码。
///
/// 与旧版 `LumiImageAttachmentMetadata` / `LumiFileAttachmentMetadata` 对齐：
/// - key `imageAttachments` → `[UserImageAttachment]` JSON
/// - key `fileAttachments` → `[UserFileAttachment]` JSON
/// AgentLoop 每轮请求前从最近一条 user 消息抽取附件，注入 LLM 请求。
public enum UserAttachmentMetadata {
    public static let imageAttachmentsKey = "imageAttachments"
    public static let fileAttachmentsKey = "fileAttachments"

    // MARK: Encode

    public static func encodeImageAttachments(
        _ attachments: [UserImageAttachment]
    ) -> [String: String] {
        encode(attachments, key: imageAttachmentsKey)
    }

    public static func encodeFileAttachments(
        _ attachments: [UserFileAttachment]
    ) -> [String: String] {
        encode(attachments, key: fileAttachmentsKey)
    }

    private static func encode<T: Encodable>(
        _ value: T,
        key: String
    ) -> [String: String] {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return [key: string]
    }

    // MARK: Decode

    public static func decodeImageAttachments(from metadata: [String: String]) -> [UserImageAttachment] {
        decode([UserImageAttachment].self, from: metadata, key: imageAttachmentsKey) ?? []
    }

    public static func decodeFileAttachments(from metadata: [String: String]) -> [UserFileAttachment] {
        decode([UserFileAttachment].self, from: metadata, key: fileAttachmentsKey) ?? []
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        from metadata: [String: String],
        key: String
    ) -> T? {
        guard let string = metadata[key], let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: Extract from history

    /// 从消息历史中抽取最近一条 user 消息携带的图片附件。
    public static func extractImageAttachments(from messages: [Message]) -> [UserImageAttachment] {
        extract(from: messages, key: imageAttachmentsKey) {
            decodeImageAttachments(from: $0)
        }
    }

    /// 从消息历史中抽取最近一条 user 消息携带的文件附件。
    public static func extractFileAttachments(from messages: [Message]) -> [UserFileAttachment] {
        extract(from: messages, key: fileAttachmentsKey) {
            decodeFileAttachments(from: $0)
        }
    }

    private static func extract(
        from messages: [Message],
        key: String,
        decode: ([String: String]) -> [UserImageAttachment]?
    ) -> [UserImageAttachment] {
        guard let latestUser = messages.reversed().first(where: { $0.role == .user }),
              latestUser.metadata[key] != nil else {
            return []
        }
        return decode(latestUser.metadata) ?? []
    }

    private static func extract(
        from messages: [Message],
        key: String,
        decode: ([String: String]) -> [UserFileAttachment]?
    ) -> [UserFileAttachment] {
        guard let latestUser = messages.reversed().first(where: { $0.role == .user }),
              latestUser.metadata[key] != nil else {
            return []
        }
        return decode(latestUser.metadata) ?? []
    }
}
