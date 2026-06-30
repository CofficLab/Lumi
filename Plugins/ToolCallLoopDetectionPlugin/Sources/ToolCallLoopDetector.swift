import Foundation
import LumiCoreKit

struct ToolCallSignatureInfo: Equatable {
    let name: String
    let arguments: String
}

struct ToolLoopPattern: Equatable {
    let toolName: String
    let toolArguments: String
    let count: Int
    let threshold: Int
}

enum ToolCallLoopDetector {
    static let repeatedToolWindowThreshold = 3
    static let recentMessageLimit = 100

    static func detect(in messages: [AgentChatMessage]) -> ToolLoopPattern? {
        let recentMessages = Array(messages.suffix(recentMessageLimit))

        var signatureCounts: [String: Int] = [:]
        var signatureDetails: [String: ToolCallSignatureInfo] = [:]

        for message in recentMessages {
            guard message.role == .assistant, let toolCalls = message.toolCalls else { continue }

            for toolCall in toolCalls where toolCall.hasResult {
                recordSignature(
                    name: toolCall.name,
                    arguments: toolCall.arguments,
                    signatureCounts: &signatureCounts,
                    signatureDetails: &signatureDetails
                )
            }
        }

        for message in recentMessages where message.role == .tool {
            guard let toolCallID = message.toolCallID,
                  let assistantMessage = findAssistantMessage(for: toolCallID, in: recentMessages),
                  let toolCalls = assistantMessage.toolCalls,
                  let toolCall = toolCalls.first(where: { $0.id == toolCallID }) else {
                continue
            }

            recordSignature(
                name: toolCall.name,
                arguments: toolCall.arguments,
                signatureCounts: &signatureCounts,
                signatureDetails: &signatureDetails
            )
        }

        for (signatureId, count) in signatureCounts {
            if count >= repeatedToolWindowThreshold,
               let info = signatureDetails[signatureId] {
                return ToolLoopPattern(
                    toolName: info.name,
                    toolArguments: info.arguments,
                    count: count,
                    threshold: repeatedToolWindowThreshold
                )
            }
        }

        return nil
    }

    private static func recordSignature(
        name: String,
        arguments: String,
        signatureCounts: inout [String: Int],
        signatureDetails: inout [String: ToolCallSignatureInfo]
    ) {
        let signatureId = "\(name):\(arguments)"
        signatureCounts[signatureId, default: 0] += 1
        if signatureDetails[signatureId] == nil {
            signatureDetails[signatureId] = ToolCallSignatureInfo(name: name, arguments: arguments)
        }
    }

    private static func findAssistantMessage(
        for toolCallID: String,
        in messages: [AgentChatMessage]
    ) -> AgentChatMessage? {
        for message in messages.reversed() {
            if message.role == .assistant,
               let toolCalls = message.toolCalls,
               toolCalls.contains(where: { $0.id == toolCallID }) {
                return message
            }
        }
        return nil
    }
}
