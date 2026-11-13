import KitAgentTool
import Combine
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import LumiLoggingKit
extension Message {
    var llmMessage: LLMMessage {
        llmMessage(toolImages: [])
    }

    func llmMessage(
        toolImages: [KitLLM.MessageImage],
        omittedArgumentKeys: [String: Set<String>] = [:],
        includesImages: Bool = true,
        imageDecoder: ImageBase64Decoder = .shared
    ) -> LLMMessage {
        // 非视觉模型不该收到图片，因此**根本不要解码**图片字节。
        //
        // 此前是「先解码、再剥离」：一张 1.5 MB 的截图解码一次约 1.2 ms，
        // 一段带图历史实测 38 ms，全部发生在主线程上，而结果随即被丢弃
        // （Issue #1268）。`includesImages == false` 时连 metadata 里的
        // base64 都不去碰。
        let userImages: [KitLLM.MessageImage] = includesImages
            ? UserAttachmentMetadata
                .decodeImageAttachments(from: metadata)
                .compactMap { attachment -> KitLLM.MessageImage? in
                    guard let data = imageDecoder.decode(attachment.base64Data) else { return nil }
                    return KitLLM.MessageImage(data: data, mimeType: attachment.mimeType)
                }
            : []
        let userFiles = role == .user
            ? UserAttachmentMetadata.decodeFileAttachments(from: metadata)
            : []
        let contentWithFileAttachments = UserAttachmentMetadata.appendingFileAttachments(
            userFiles,
            to: content
        )

        return LLMMessage(
            role: KitLLM.MessageRole(rawValue: role.rawValue) ?? .unknown,
            content: contentWithFileAttachments,
            toolCalls: toolCalls?.map { toolCall in
                let arguments = ToolCallContextArguments.scrubbed(
                    toolCall.arguments,
                    omitting: omittedArgumentKeys[toolCall.name] ?? []
                )
                return LLMToolCall(id: toolCall.id, name: toolCall.name, arguments: arguments)
            },
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            redactedThinking: redactedThinkingData?.map {
                KitLLM.LLMRedactedThinkingBlock(data: $0)
            },
            // 工具失败必须在协议层可见，不能被当成普通成功文本。
            isError: isError,
            // 工具结果图片必须挂在独立的 tool 消息上，不能成为 assistant content。
            images: role == .user ? userImages : (role == .tool ? toolImages : [])
        )
    }
}

/// 收集各工具声明的不进入模型上下文的参数键，按工具名索引。
///
/// 声明为空的工具不进入结果，`llmMessages` 因此对它们保持原样。
func contextOmittedArgumentKeys(for tools: [any SuperAgentTool]) -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for tool in tools {
        let keys = tool.contextOmittedArgumentKeys
        guard !keys.isEmpty else { continue }
        result[tool.name] = keys
    }
    return result
}

/// 将持久化消息转换为 LLM 消息，并把 assistant 工具调用结果中的图片
/// 关联到对应的 tool 消息。图片仍只保存在 assistant 的嵌套结果中，避免
/// 为传输格式额外复制一份大体积 base64 数据。
///
/// - Parameter includesImages: 是否携带图片。`false` 表示目标模型不支持
///   视觉（`LLMModelInfo.supportsVision == false`），此时**不解码任何图片
///   字节**——此前是「先解码再剥离」，图片白白解码一遍随即丢弃
///   （Issue #1268）。
func llmMessages(
    from messages: [Message],
    omittedArgumentKeys: [String: Set<String>] = [:],
    includesImages: Bool = true,
    imageDecoder: ImageBase64Decoder = .shared
) -> [LLMMessage] {
    var pendingImagesByToolCallID: [String: [[KitLLM.MessageImage]]] = [:]
    if includesImages {
        for message in messages where message.role == .assistant {
            for toolCall in message.toolCalls ?? [] {
                let images = toolCall.result?.imageAttachments.compactMap { attachment -> KitLLM.MessageImage? in
                    guard let data = imageDecoder.decode(attachment.data) else { return nil }
                    return KitLLM.MessageImage(data: data, mimeType: attachment.mimeType)
                } ?? []
                guard !images.isEmpty else { continue }
                pendingImagesByToolCallID[toolCall.id, default: []].append(images)
            }
        }
    }

    var result: [LLMMessage] = []
    result.reserveCapacity(messages.count)
    for message in messages {
        var toolImages: [KitLLM.MessageImage] = []
        if includesImages,
           message.role == .tool,
           let toolCallID = message.toolCallID,
           var pendingImages = pendingImagesByToolCallID[toolCallID],
           !pendingImages.isEmpty {
            toolImages = pendingImages.removeFirst()
            pendingImagesByToolCallID[toolCallID] = pendingImages
        }
        result.append(
            message.llmMessage(
                toolImages: toolImages,
                omittedArgumentKeys: omittedArgumentKeys,
                includesImages: includesImages,
                imageDecoder: imageDecoder
            )
        )
    }
    return result
}

/// 在后台线程把持久化消息转换为 LLM 消息。
///
/// ## 为什么需要异步版本
///
/// `llmMessages(from:)` 是同步函数，调用点在 `@MainActor` 的
/// `AgentLoopManager` 上。它要遍历全部历史消息、JSON 解码每条消息的
/// 附件 metadata、并解码每张图片的 base64——实测一段带图的十消息历史
/// 耗时 38 ms，全部占住主线程（Issue #1268）。
///
/// ## 为什么必须是 `Task.detached`
///
/// 实测（Debug 构建）从 `@MainActor` 调用方触发时的线程归属：
///
/// | 调用方式 | 执行线程 |
/// |---|---|
/// | 直接调用 `nonisolated` 静态函数 | **主线程** |
/// | `Task { … }`（继承 actor 上下文） | **主线程** |
/// | `Task.detached { … }` | 后台线程 ✅
///
/// `nonisolated` 只表示「这个函数不要求 actor 隔离」，**不代表它会自动
/// 换线程**；`Task {}` 又会继承当前 actor 上下文。只有 `Task.detached`
/// 才是真正脱离当前执行上下文的。
///
/// 转换结果 `[LLMMessage]` 是 `Sendable`，可以安全地带回主线程。
///
/// - Parameters:
///   - messages: 已准备好的历史消息快照。
///   - omittedArgumentKeys: 各工具声明的不进入模型上下文的参数键。
///   - includesImages: 是否携带图片；`false` 时不解码任何图片字节。
/// - Returns: 转换后的 LLM 消息。
func llmMessagesOffMainActor(
    from messages: [Message],
    omittedArgumentKeys: [String: Set<String>] = [:],
    includesImages: Bool = true,
    imageDecoder: ImageBase64Decoder = .shared
) async -> [LLMMessage] {
    await Task.detached(priority: .userInitiated) {
        llmMessages(
            from: messages,
            omittedArgumentKeys: omittedArgumentKeys,
            includesImages: includesImages,
            imageDecoder: imageDecoder
        )
    }.value
}

/// 把本次请求的临时恢复提示插在最新 user 消息之前，保住前缀缓存。
///
/// 恢复提示每轮可能不同（仅重试时出现），插 0 会让其后整段稳定历史的
/// 前缀缓存失效。锚定最新 user 之前与 Goal/RAG 注入约定一致；没有 user
/// 消息时回退到末尾。提示只是临时 system message，不写入会话历史。
func insertingRecoveryHint(_ hint: String, into messages: [LLMMessage]) -> [LLMMessage] {
    var result = messages
    let anchor = result.lastIndex(where: { $0.role == .user }) ?? result.endIndex
    result.insert(LLMMessage(role: .system, content: hint), at: anchor)
    return result
}

/// 将生命周期钩子返回的 LLM 消息恢复为 AgentLoop 的消息模型。
/// 工具调用声明必须保留，否则后续的 tool_result 没有对应的 assistant tool_use。
func messageFromLLMMessage(_ message: LLMMessage, conversationID: UUID) -> Message {
    let metadata: [String: String]
    if message.role == .user, !message.images.isEmpty {
        metadata = UserAttachmentMetadata.encodeImageAttachments(
            message.images.map {
                UserImageAttachment(
                    mimeType: $0.mimeType,
                    base64Data: $0.data.base64EncodedString()
                )
            }
        )
    } else {
        metadata = [:]
    }

    return Message(
        conversationID: conversationID,
        role: .init(rawValue: message.role.rawValue) ?? .system,
        content: message.content,
        metadata: metadata,
        isError: message.isError,
        toolCallID: message.toolCallID,
        reasoningContent: message.reasoningContent,
        toolCalls: message.toolCalls?.map {
            MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
        }
    )
}

// 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
typealias AgentLoopToolCall = KitAgentTool.ToolCall
