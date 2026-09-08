import Foundation
import KitLLM

/// Makes provider-supplied tool-call IDs safe for the whole conversation.
///
/// Some OpenAI-compatible gateways restart their tool-call counter for every
/// response (for example, returning `ls_0` again after it was already used).
/// AgentLoop needs IDs to remain unique across the messages it sends back to
/// the provider, otherwise ToolManager's same-turn idempotency check can reuse
/// an earlier completed job and leave the new call pending forever.
enum ToolCallIdentityNormalizer {
    static func ids(in messages: [LLMMessage]) -> Set<String> {
        messages.reduce(into: Set<String>()) { ids, message in
            ids.formUnion(message.toolCalls?.map(\.id) ?? [])
            if let toolCallID = message.toolCallID, !toolCallID.isEmpty {
                ids.insert(toolCallID)
            }
        }
    }

    static func normalize(
        _ response: LLMResponse,
        avoiding usedToolCallIDs: Set<String>
    ) -> LLMResponse {
        guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
            return response
        }

        var occupiedIDs = usedToolCallIDs
        let normalizedToolCalls = toolCalls.map { toolCall in
            let providerID = toolCall.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedID: String
            if !providerID.isEmpty, !occupiedIDs.contains(providerID) {
                normalizedID = providerID
            } else {
                normalizedID = makeUniqueID(avoiding: occupiedIDs)
            }
            occupiedIDs.insert(normalizedID)
            return LLMToolCall(
                id: normalizedID,
                name: toolCall.name,
                arguments: toolCall.arguments
            )
        }

        return LLMResponse(
            content: response.content,
            model: response.model,
            toolCalls: normalizedToolCalls,
            reasoningContent: response.reasoningContent,
            inputTokenCount: response.inputTokenCount,
            outputTokenCount: response.outputTokenCount,
            cachedInputTokenCount: response.cachedInputTokenCount,
            cacheWriteInputTokenCount: response.cacheWriteInputTokenCount,
            cacheTotalInputTokenCount: response.cacheTotalInputTokenCount,
            responseID: response.responseID,
            rawResponseJSON: response.rawResponseJSON,
            rawStreamEventsJSON: response.rawStreamEventsJSON,
            stopReason: response.stopReason
        )
    }

    private static func makeUniqueID(avoiding occupiedIDs: Set<String>) -> String {
        var id: String
        repeat {
            id = "call_lumi_\(UUID().uuidString.lowercased())"
        } while occupiedIDs.contains(id)
        return id
    }
}
