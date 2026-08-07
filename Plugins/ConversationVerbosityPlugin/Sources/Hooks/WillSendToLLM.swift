import Foundation
import LumiKernel

/// Verbosity willSendToLLM hook.
///
/// Adds the selected response-style instruction as a transient system
/// message. AgentTurnRunner later merges system fragments before sending the
/// provider request, so this prompt is never persisted in the conversation.
@MainActor
public struct VerbosityWillSendToLLMHook {
    private static let promptMarker = "verbosityPrompt"

    public init() {}

    public func execute(
        kernel: LumiKernel,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        let conversationID = messages.first?.conversationID
            ?? kernel.conversations?.selectedConversationID

        guard conversationID != nil else { return messages }

        // 优先使用对话级别的详细程度；无选中对话时回退到全局设置
        let verbosity: LumiResponseVerbosity = {
            guard let conversations = kernel.conversations else {
                return .defaultVerbosity
            }
            if let conversationID,
               conversations.selectedConversationID == conversationID {
                return conversations.verbosity(for: conversationID)
            }
            return conversations.globalVerbosity
        }()
        let withoutPreviousPrompt = messages.filter {
            $0.metadata[Self.promptMarker] != "true"
        }

        let prompt = LumiChatMessage(
            conversationID: conversationID!,
            role: .system,
            content: Self.responseStylePrompt(for: verbosity),
            metadata: [Self.promptMarker: "true"]
        )

        return [prompt] + withoutPreviousPrompt
    }

    static func responseStylePrompt(for verbosity: LumiResponseVerbosity) -> String {
        switch verbosity {
        case .brief:
            return """
            ## Response style: V1 (brief)
            Give the user the direct answer first. Keep the response concise and focused on the requested outcome. Use short paragraphs or a small number of bullets when useful. Omit unnecessary background, repetition, and optional explanations, but do not omit required steps, warnings, errors, or information needed to act on the answer. Do not expose private chain-of-thought; provide only a concise, verifiable explanation when explanation is necessary.
            """
        case .standard:
            return """
            ## Response style: V2 (standard)
            Provide the answer first, followed by the necessary explanation, steps, and important caveats. Keep the response clear and reasonably concise. Include enough context for the user to understand and act on the result. Do not expose private chain-of-thought; summarize reasoning with concise, verifiable explanations.
            """
        case .detailed:
            return """
            ## Response style: V3 (detailed)
            Provide a thorough answer with relevant background, reasoning summaries, implementation details, alternatives, and important edge cases when they help the user. Organize longer responses with clear sections or bullets. Remain focused on the request and do not expose private chain-of-thought; provide concise, verifiable reasoning summaries instead.
            """
        }
    }
}
