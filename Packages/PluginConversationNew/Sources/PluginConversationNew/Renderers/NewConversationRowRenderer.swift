import Foundation
import KitAgentTool
import ProviderMessageRendering
import SwiftUI

/// `create_new_conversation` 工具结果的专用行渲染器。
///
/// 数据流：
/// 1. LLM 调用 `create_new_conversation`，工具返回人类可读正文 + 末尾 JSON 代码块；
/// 2. 本渲染器命中 `canRender`（工具名匹配且能解码 payload），从
///    `ToolCallResult.content` 提取 JSON 并解码为 `NewConversationSuggestion`；
/// 3. 渲染「建议换个话题」卡片，按钮点击后切到新对话并自动发送首条消息；
/// 4. 任何解析失败都回退到默认工具文本视图，不丢信息。
public struct NewConversationRowRenderer: ToolCallRowRenderer {
    public static let id = "new-conversation-row"
    /// 高于 `ToolApprovalRowRenderer`(120)? 不需要——本工具不走授权路径，
    /// 但高于默认卡片路径即可，这里取 130 保持专属优先。
    public static let priority = 130

    private let conversations: NewChatCapability?
    private let sender: NewChatStarting?

    /// 依赖能力协议为插件内部类型，故初始化器同为 internal。
    init(
        conversations: NewChatCapability? = nil,
        sender: NewChatStarting? = nil
    ) {
        self.conversations = conversations
        self.sender = sender
    }

    public func canRender(toolCall: ToolCall) -> Bool {
        guard toolCall.name == CreateNewConversationTool.toolName,
              let content = toolCall.result?.content else {
            return false
        }
        return Self.decodeSuggestion(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let suggestion = Self.decodeSuggestion(from: content) else {
            // 回退：展示工具返回的原始文本，避免信息丢失。
            return AnyView(
                Text(toolCall.result?.content ?? pluginLocalization.string("New conversation"))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            )
        }

        return AnyView(
            NewConversationSuggestionCard(
                suggestion: suggestion,
                conversations: conversations,
                sender: sender
            )
        )
    }

    /// 从工具返回内容中提取末尾 ```json ... ``` 代码块并解码。
    static func decodeSuggestion(from content: String) -> NewConversationSuggestion? {
        guard let json = extractJSON(from: content),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(NewConversationSuggestion.self, from: data)
    }

    /// 从工具返回内容中提取第一个 ```json ... ``` 代码块的内容。
    static func extractJSON(from content: String) -> String? {
        let marker = "```json"
        guard let start = content.range(of: marker)?.upperBound else { return nil }
        let rest = content[start...]
        guard let end = rest.range(of: "```")?.lowerBound else { return nil }
        let json = rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return json.isEmpty ? nil : json
    }
}
