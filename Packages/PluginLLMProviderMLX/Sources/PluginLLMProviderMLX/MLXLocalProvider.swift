import Foundation
import KitLLM

@MainActor
final class MLXLocalProvider: SuperLLMProvider, LLMStreamingProviding {
    let providerInfo: LLMProviderInfo
    var providerID: String { providerInfo.id }

    init(providerID: String, name: String) {
        let models = MLXProviderCatalog.models(for: providerID)
        providerInfo = LLMProviderInfo(
            id: providerID,
            displayName: name,
            description: "Apple Silicon 上的 MLX 本地模型",
            defaultModel: models.first?.id ?? "",
            models: models.map {
                LLMModelInfo(
                    id: $0.id,
                    displayName: $0.displayName,
                    contextWindowSize: $0.contextWindowSize,
                    supportsVision: $0.supportsVision,
                    supportsTools: $0.supportsTools
                )
            },
            isLocal: true,
            websiteURL: URL(string: "https://github.com/ml-explore/mlx-swift-lm")
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let accumulator = MLXTextAccumulator()
        let response = try await streamComplete(request) { chunk in
            accumulator.append(chunk.content ?? "")
        }
        return LLMResponse(content: accumulator.value, model: response.model, toolCalls: response.toolCalls)
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let modelID = request.model ?? providerInfo.defaultModel
        guard providerInfo.contains(model: modelID) else {
            throw MLXProviderError.modelNotAvailable(modelID)
        }
        return try await MLXRuntime.shared.generate(request: request, modelID: modelID, onChunk: onChunk)
    }
}
