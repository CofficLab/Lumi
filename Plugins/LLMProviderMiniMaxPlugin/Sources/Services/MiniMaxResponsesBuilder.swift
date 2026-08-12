import Foundation
import LLMKit
import LumiKernel

enum MiniMaxResponsesBuilder {
    static func reasoningEffort(_ effort: LumiReasoningEffort?) -> MiniMaxResponsesReasoning? {
        guard let effort else { return nil }
        let wireValue: String
        switch effort {
        case .low: wireValue = "low"
        case .medium: wireValue = "medium"
        case .high: wireValue = "high"
        case .xhigh: wireValue = "high"
        case .max: wireValue = "high"
        }
        return MiniMaxResponsesReasoning(effort: wireValue)
    }

    static func build(_ request: LumiLLMRequest) throws -> MiniMaxResponsesRequest {
        let systemMessages = request.messages.filter { $0.role == .system }
        let instructions = systemMessages.map(\.content).filter { !$0.isEmpty }.joined(separator: "\n\n")

        let nonSystem = request.messages.filter {
            $0.role != .system && $0.role != .error && $0.role != .status
        }

        let input: MiniMaxResponsesInput
        if nonSystem.isEmpty {
            input = .history([])
        } else if nonSystem.count == 1, let only = nonSystem.first, only.role == .user {
            input = .simple(only.content)
        } else {
            input = .history(try buildHistory(nonSystem))
        }

        // 函数名仅允许字母/数字/_/-，带点号等非法字符的工具名须转义，否则整包请求被 400 拒绝。
        let tools: [MiniMaxResponsesTool]? = request.tools.isEmpty ? nil : request.tools.map { tool in
            let params: [String: Any] = {
                if let dict = tool.inputSchema.anyValue as? [String: Any] { return dict }
                return [:]
            }()
            return MiniMaxResponsesTool(name: LLMToolNameSanitizer.sanitize(tool.name), description: tool.toolDescription, parameters: params)
        }

        return MiniMaxResponsesRequest(
            model: request.model,
            input: input,
            instructions: instructions.isEmpty ? nil : instructions,
            maxOutputTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stream: true,
            tools: tools,
            toolChoice: request.toolChoice,
            reasoning: reasoningEffort(request.reasoningEffort),
            metadata: nil
        )
    }

    private static func buildHistory(_ messages: [LumiChatMessage]) throws -> [MiniMaxResponsesInputItem] {
        var items: [MiniMaxResponsesInputItem] = []
        for message in messages {
            switch message.role {
            case .user:
                items.append(.init(role: "user", content: message.content))
            case .assistant:
                var contentParts: [String] = []
                if !message.content.isEmpty {
                    contentParts.append(message.content)
                }
                if let toolCalls = message.toolCalls {
                    for call in toolCalls {
                        if !contentParts.isEmpty {
                            items.append(.init(role: "assistant", content: contentParts.joined(separator: "\n")))
                            contentParts = []
                        }
                        // 历史消息回传同样要转义，否则下一轮请求仍会被供应商 400 拒绝。
                        items.append(.init(functionCall: call.id, name: LLMToolNameSanitizer.sanitize(call.name), arguments: call.arguments))
                    }
                } else if !contentParts.isEmpty {
                    items.append(.init(role: "assistant", content: contentParts.joined(separator: "\n")))
                }
            case .tool:
                guard let callID = message.toolCallID else { continue }
                items.append(.init(functionCallOutput: callID, output: message.content))
            case .system, .error, .status:
                break
            }
        }
        return items
    }
}
