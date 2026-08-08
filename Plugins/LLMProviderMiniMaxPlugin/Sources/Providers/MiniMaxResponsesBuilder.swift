import Foundation
import LumiKernel

enum MiniMaxResponsesBuilder {
    /// Maps LumiReasoningEffort to the wire format for Responses API.
    /// - nil effort means use model/server default (which is "none" = no thinking)
    /// - .low/.medium/.high/.xhigh/.max map to Responses API effort values
    static func reasoningEffort(_ effort: LumiReasoningEffort?) -> MiniMaxResponsesReasoning? {
        guard let effort else { return nil }
        let wireValue: String
        switch effort {
        case .low: wireValue = "low"
        case .medium: wireValue = "medium"
        case .high: wireValue = "high"
        case .xhigh: wireValue = "high"  // Responses API has no xhigh, cap at high
        case .max: wireValue = "high"    // Responses API has no max, cap at high
        }
        return MiniMaxResponsesReasoning(effort: wireValue)
    }

    static func build(_ request: LumiLLMRequest) throws -> MiniMaxResponsesRequest {
        // Collect system messages for the instructions field
        let systemMessages = request.messages.filter { $0.role == .system }
        let instructions = systemMessages
            .map(\.content)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        // Collect non-system, non-error, non-status messages for input
        let nonSystem = request.messages.filter {
            $0.role != .system && $0.role != .error && $0.role != .status
        }

        // Determine input format
        let input: MiniMaxResponsesInput
        if nonSystem.isEmpty {
            // All messages were system/error/status — use empty history
            input = .history([])
        } else if nonSystem.count == 1, let only = nonSystem.first, only.role == .user {
            // Simple single-user-message input → plain string
            input = .simple(only.content)
        } else {
            // Multi-turn conversation → history array
            input = .history(try buildHistory(nonSystem))
        }

        let tools: [MiniMaxResponsesTool]? = request.tools.isEmpty ? nil : request.tools.map {
            MiniMaxResponsesTool(
                name: $0.name,
                description: $0.toolDescription,
                parameters: $0.inputSchema.anyValue
            )
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
                        // Assistant text before tool call
                        if !contentParts.isEmpty {
                            items.append(.init(role: "assistant", content: contentParts.joined(separator: "\n")))
                            contentParts = []
                        }
                        items.append(.init(functionCall: call.id, name: call.name, arguments: call.arguments))
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
