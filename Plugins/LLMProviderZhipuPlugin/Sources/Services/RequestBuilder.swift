import AgentToolKit
import Foundation
import LumiCoreKit

/// 智谱 API 请求体构建
enum RequestBuilder {
    static let defaultMaxTokens = 8192

    static func buildBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        let systemParts = messages
            .filter { $0.role == .system }
            .map(\.content)
            .filter { !$0.isEmpty }
        let systemMessage = systemParts.isEmpty
            ? systemPrompt
            : systemParts.joined(separator: "\n\n")

        let conversationMessages = messages
            .filter { $0.shouldSendToLLM }
            .map { MessageTransformer.transform($0) }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": defaultMaxTokens,
            "system": systemMessage,
            "messages": conversationMessages,
        ]

        if let tools, !tools.isEmpty {
            body["tools"] = tools.map { MessageTransformer.formatTool($0) }
        }

        return body
    }

    static func buildStreamingBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        var body = try buildBody(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
        body["stream"] = true
        return body
    }
}
