import Foundation
import LumiCoreKit

@available(macOS 14.0, *)
public final class MLXLumiProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "mlx",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local models via Apple MLX", bundle: .module),
        defaultModel: MLXModels.toolModels.first?.id ?? "mlx-community/Qwen3.5-9B-4bit",
        availableModels: MLXModels.toolModels.map(\.id),
        isLocal: true
    )

    public init() {}

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw MLXLumiError.missingConversation
        }

        let result = try await Self.generate(
            request: request,
            onChunk: onChunk
        )

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: result,
            providerID: Self.info.id,
            modelName: request.model
        )
    }

    @MainActor
    private static func generate(
        request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> String {
        let service = MLXInferenceService()
        try await service.loadModel(id: request.model)

        let mlxMessages = request.messages.compactMap { message -> MLXChatMessage? in
            switch message.role {
            case .system:
                return MLXChatMessage(role: .system, content: message.content)
            case .user:
                return MLXChatMessage(role: .user, content: message.content)
            case .assistant:
                return MLXChatMessage(role: .assistant, content: message.content)
            case .tool, .error, .status:
                return nil
            }
        }

        guard !mlxMessages.isEmpty else {
            throw MLXLumiError.emptyPrompt
        }

        var content = ""
        for await chunk in service.chat(messages: mlxMessages) {
            switch chunk {
            case .text(let text):
                content += text
                await onChunk(LumiStreamChunk(content: text, eventTitle: "生成中"))
            case .error(let message):
                throw MLXLumiError.generationFailed(message)
            case .toolCall:
                break
            }
        }

        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
        return content
    }
}

enum MLXLumiError: LocalizedError {
    case missingConversation
    case emptyPrompt
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "Missing conversation ID"
        case .emptyPrompt:
            return "Prompt is empty"
        case .generationFailed(let message):
            return message
        }
    }
}
