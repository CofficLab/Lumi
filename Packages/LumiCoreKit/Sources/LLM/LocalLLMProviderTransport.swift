import Foundation
import AgentToolKit
import HttpKit
import LLMKit

/// 本地供应商在 `streamChat` / `sendMessage` 中可复用的传输 helper（非协议默认实现）。
public enum LocalLLMProviderTransport {
    public static func streamChat<P: SuperLocalLLMProvider>(
        provider: P,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        try await provider.ensureModelReady(modelId: config.model)
        let images = messages.last(where: { $0.role == .user })?.images ?? []
        do {
            return try await provider.streamChat(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: nil,
                images: images,
                onChunk: onChunk
            )
        } catch let error as LLMServiceError {
            throw error
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }

    public static func sendMessage<P: SuperLocalLLMProvider>(
        provider: P,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await provider.ensureModelReady(modelId: config.model)
        let images = messages.last(where: { $0.role == .user })?.images ?? []
        do {
            return try await provider.sendMessage(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: nil,
                images: images
            )
        } catch let error as LLMServiceError {
            throw error
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }
}
