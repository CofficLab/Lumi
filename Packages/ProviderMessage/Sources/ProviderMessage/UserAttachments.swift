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
/// 二进制附件保留 `base64Data`，并可带 `localPath` 供本地 Agent 工具解析。
public struct UserFileAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let mimeType: String
    public let base64Data: String?
    public let textContent: String?
    /// Original local path for files that should be inspected by local Agent tools.
    /// Optional so attachments persisted by older app versions continue to decode.
    public let localPath: String?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        base64Data: String? = nil,
        textContent: String? = nil,
        localPath: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.textContent = textContent
        self.localPath = localPath
    }
}

/// 将本地文件转换为可随用户消息发送的附件。
///
/// 附件保留原始字节、可识别的 UTF-8 文本和来源路径：文本文件由模型直接读取，
/// 二进制文件可由本地 Agent 工具通过路径处理。
public enum UserFileAttachmentLoader {
    public static func load(from url: URL) throws -> UserFileAttachment {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let mimeType = UTType(filenameExtension: url.pathExtension.lowercased())?.preferredMIMEType
            ?? "application/octet-stream"

        return UserFileAttachment(
            fileName: url.lastPathComponent,
            mimeType: mimeType,
            base64Data: data.base64EncodedString(),
            textContent: String(data: data, encoding: .utf8),
            localPath: url.path
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

    /// 将文本文件附件追加到用户消息正文，供不支持独立文件字段的 LLM 协议使用。
    ///
    /// 二进制附件不把 base64 字节混入提示词；有本地路径时提示 Agent 调用本地工具处理。
    public static func appendingFileAttachments(
        _ attachments: [UserFileAttachment],
        to content: String
    ) -> String {
        guard !attachments.isEmpty else { return content }

        let renderedAttachments = attachments.map { attachment in
            let name = escapeAttribute(attachment.fileName)
            let mimeType = escapeAttribute(attachment.mimeType)
            let body: String
            if let textContent = attachment.textContent {
                body = textContent
            } else if let localPath = attachment.localPath {
                let path = escapeText(localPath)
                body = """
                [Binary file; content is not decoded. MIME type: \(attachment.mimeType)]
                Local file path: \(path)
                Use the local run_command tool to inspect this file. For ZIP archives, list the entries first, then extract the needed files to a temporary directory and read their contents. Do not execute files from the archive.
                """
            } else {
                body = "[Binary file attachment; content is not decoded. MIME type: \(attachment.mimeType)]"
            }

            return """
            <attached_file name="\(name)" mime_type="\(mimeType)">
            \(body)
            </attached_file>
            """
        }.joined(separator: "\n\n")

        guard !content.isEmpty else { return renderedAttachments }
        return "\(content)\n\n\(renderedAttachments)"
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

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
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
