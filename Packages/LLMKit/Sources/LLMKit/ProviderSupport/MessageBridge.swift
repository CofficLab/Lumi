import Foundation
import KernelLumi
import os
import SuperLogKit

// MARK: - LumiVisionMessageSupport

/// Converts KernelLumi messages → LLMKit ChatMessage for provider consumption.
///
/// LumiVisionMessageSupport.preparedMessages(for:) is the central entry-point used by
/// LumiStreamingRequestSupport to transform a LumiLLMRequest into the provider-specific
/// message array.
public enum LumiVisionMessageSupport: SuperLog {
    public static let emoji = "🌉"
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.message-bridge")
    static let verbose = false

    public static func preparedMessages(for request: LumiLLMRequest) -> [ChatMessage] {
        var messages = request.messages.map(convert)
        if Self.verbose {
            let inputContentChars = request.messages.reduce(0) { $0 + $1.content.count }
            let inputMetadataChars = request.messages.reduce(0) {
                $0 + $1.metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
            }
            Self.logger.info("\(Self.t)preparedMessages start messages=\(request.messages.count) contentChars=\(inputContentChars) metadataChars=\(inputMetadataChars) requestImages=\(request.imageAttachments.count) requestFiles=\(request.fileAttachments.count)")
        }
        attachRequestImages(&messages, attachments: request.imageAttachments)
        injectFileAttachments(&messages, attachments: request.fileAttachments)
        let prepared = LLMMessagePreparer.prepare(messages)
        if Self.verbose {
            let outputContentChars = prepared.reduce(0) { $0 + $1.content.count }
            let imageCount = prepared.reduce(0) { $0 + $1.images.count }
            let imageBytes = prepared.reduce(0) { partial, message in
                partial + message.images.reduce(0) { $0 + $1.data.count }
            }
            Self.logger.info("\(Self.t)preparedMessages done messages=\(prepared.count) contentChars=\(outputContentChars) imageCount=\(imageCount) imageBytes=\(imageBytes)")
        }
        return prepared
    }

    public static func convert(_ message: LumiChatMessage) -> ChatMessage {
        ChatMessage(
            role: convertRole(message.role),
            content: message.content,
            toolCalls: message.toolCalls?.map {
                ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            toolCallID: message.toolCallID,
            reasoningContent: message.reasoningContent,
            images: messageImages(from: message.metadata)
        )
    }

    /// 进程级缓存:把已解码的图片(by base64-JSON 文本)缓存起来。
    /// `preparedMessages` 每轮请求会对全部历史消息重跑解码,多模态长对话里
    /// `Data(base64Encoded:)` 的 CPU 开销会被重复放大。同一份 imageAttachments
    /// JSON 解码结果恒定,故以 JSON 字符串本身作为 key 缓存。
    /// NSCache 线程安全且在内存压力下自动驱逐,适合此场景。
    // NSCache 本身线程安全(内部加锁),CachedMessageImages 的 images 是 let,
    // 故全局共享访问是安全的;用 nonisolated(unsafe) 向编译器声明这一点。
    private nonisolated(unsafe) static let imageDecodeCache: NSCache<NSString, CachedMessageImages> = {
        let cache = NSCache<NSString, CachedMessageImages>()
        // 解码后的图片字节数可能不小(每张几百 KB~几 MB),给一个温和上限,
        // 让 NSCache 在内存压力下优先驱逐最久未用的条目,避免长会话堆积。
        cache.totalCostLimit = 64 * 1024 * 1024 // 64 MB
        return cache
    }()

    /// NSCache 只能持有 class 类型,用包装类承载 `[MessageImage]`(值类型)。
    private final class CachedMessageImages: NSObject {
        let images: [MessageImage]
        init(_ images: [MessageImage]) { self.images = images }
    }

    public static func messageImages(from metadata: [String: String]) -> [MessageImage] {
        guard let json = metadata["imageAttachments"] else {
            return []
        }
        let cacheKey = NSString(string: json)
        if let cached = imageDecodeCache.object(forKey: cacheKey) {
            return cached.images
        }
        guard let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder().decode([LumiImageAttachment].self, from: data)
        else {
            return []
        }
        let images = attachments.compactMap { attachment -> MessageImage? in
            guard let imageData = Data(base64Encoded: attachment.base64Data) else {
                return nil
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)decoded message image file=\(attachment.fileName ?? "nil") base64Chars=\(attachment.base64Data.count) bytes=\(imageData.count) mimeType=\(attachment.mimeType)")
            }
            return MessageImage(data: imageData, mimeType: attachment.mimeType)
        }
        imageDecodeCache.setObject(
            CachedMessageImages(images),
            forKey: cacheKey,
            cost: images.reduce(0) { $0 + $1.data.count }
        )
        return images
    }

    private static func attachRequestImages(
        _ messages: inout [ChatMessage],
        attachments: [LumiImageAttachment]
    ) {
        let images = messageImages(
            from: ["imageAttachments": encodeAttachments(attachments) ?? ""]
        )
        guard !images.isEmpty,
              let lastUserIndex = messages.lastIndex(where: { $0.role == .user })
        else {
            return
        }
        if messages[lastUserIndex].images.isEmpty {
            messages[lastUserIndex].images = images
            if Self.verbose {
                let imageBytes = images.reduce(0) { $0 + $1.data.count }
                Self.logger.info("\(Self.t)attached request images lastUserIndex=\(lastUserIndex) images=\(images.count) imageBytes=\(imageBytes)")
            }
        }
    }

    private static func encodeAttachments(_ attachments: [LumiImageAttachment]) -> String? {
        guard let data = try? JSONEncoder().encode(attachments),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    /// 把文件附件的文本内容注入最后一条 user 消息。
    ///
    /// 文本类文件(代码/配置/文本等可 UTF-8 解码的文件)用围栏块前置到用户消息正文,
    /// 这样对任何 provider 都能立即工作(无需扩展 content part / adapter)。
    /// 二进制文件(`textContent == nil`)在此处只放一个简短的占位标注,告知模型有该文件。
    private static func injectFileAttachments(
        _ messages: inout [ChatMessage],
        attachments: [LumiFileAttachment]
    ) {
        guard !attachments.isEmpty,
              let lastUserIndex = messages.lastIndex(where: { $0.role == .user })
        else {
            return
        }

        let blocks = attachments.map { attachment -> String in
            if let text = attachment.textContent {
                return "<file name=\"\(attachment.fileName)\">\n\(text)\n</file>"
            } else {
                return "<file name=\"\(attachment.fileName)\">\n[Binary file: \(attachment.mimeType), \(attachment.base64Data.count) base64 chars — content not inlined]\n</file>"
            }
        }
        let injected = blocks.joined(separator: "\n\n")
        let original = messages[lastUserIndex].content
        messages[lastUserIndex].content = injected + "\n\n" + original
        if Self.verbose {
            let fileBase64Chars = attachments.reduce(0) { $0 + $1.base64Data.count }
            let fileTextChars = attachments.reduce(0) { $0 + ($1.textContent?.count ?? 0) }
            Self.logger.info("\(Self.t)injected file attachments lastUserIndex=\(lastUserIndex) files=\(attachments.count) injectedChars=\(injected.count) originalUserChars=\(original.count) fileBase64Chars=\(fileBase64Chars) fileTextChars=\(fileTextChars)")
        }
    }

    private static func convertRole(_ role: LumiChatMessageRole) -> MessageRole {
        switch role {
        case .system:   return .system
        case .user:     return .user
        case .assistant: return .assistant
        case .tool:     return .tool
        case .error, .status: return .error
        }
    }
}

// MARK: - LumiLLMRequestMessages

/// Thin bridge: LumiLLMRequest → provider-ready ChatMessage array.
///
/// Delegates to LumiVisionMessageSupport for the actual conversion.
public enum LumiLLMRequestMessages {
    public static func preparedForProvider(_ request: LumiLLMRequest) -> [ChatMessage] {
        LumiVisionMessageSupport.preparedMessages(for: request)
    }
}

// MARK: - LumiToolSchema

/// Wraps a LumiAgentTool (KernelLumi) as LLMToolSchemaProviding (LLMKit).
public struct LumiToolSchema: LLMToolSchemaProviding {
    public let name: String
    public let toolDescription: String
    public let inputSchema: [String: Any]

    public init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
