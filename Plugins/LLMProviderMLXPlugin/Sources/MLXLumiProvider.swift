import AgentToolKit
import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

@available(macOS 14.0, *)
public final class MLXLumiProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "mlx",
        displayName: LumiPluginLocalization.string("MLX", bundle: .module),
        description: LumiPluginLocalization.string("Local models via Apple MLX", bundle: .module),
        defaultModel: MLXModels.toolModels.first?.id ?? "mlx-community/Qwen3.5-9B-4bit",
        availableModels: MLXModels.toolModels.map(\.id),
        isLocal: true,
        modelCapabilities: Dictionary(uniqueKeysWithValues: MLXModels.toolModels.map {
            ($0.id, LumiModelCapabilities(supportsVision: $0.supportsVision, supportsTools: $0.supportsTools))
        }),
        websiteURL: URL(string: "https://github.com/ml-explore/mlx")!
    )

    public init() {}

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        if Self.info.availableModels.contains(model) {
            return .available
        }
        return .unavailable(reason: "模型 \(model) 未注册或不可用")
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

        let preparedMessages = LumiVisionMessageSupport.preparedMessages(for: request)
        let mlxMessages = preparedMessages.compactMap { message -> MLXChatMessage? in
            switch message.role {
            case .system:
                return MLXChatMessage(role: .system, content: message.content)
            case .user:
                let images = message.images.map {
                    ImageAttachment(data: $0.data, mimeType: $0.mimeType)
                }
                return MLXChatMessage(role: .user, content: message.content, images: images)
            case .assistant:
                return MLXChatMessage(role: .assistant, content: message.content)
            case .tool, .error, .status, .unknown:
                return nil
            }
        }

        guard !mlxMessages.isEmpty else {
            throw MLXLumiError.emptyPrompt
        }

        let requestImages = request.imageAttachments.compactMap { attachment -> ImageAttachment? in
            guard let data = Data(base64Encoded: attachment.base64Data) else { return nil }
            return ImageAttachment(data: data, mimeType: attachment.mimeType)
        }

        var content = ""
        for await chunk in service.chat(messages: mlxMessages, images: requestImages) {
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
