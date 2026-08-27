import Foundation
import Combine
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

extension MLXLocalProvider: LLMModelDownloadProviding {
    var downloadState: LLMModelDownloadState {
        MLXDownloadManager.shared.downloadState
    }

    var downloadStatePublisher: AnyPublisher<LLMModelDownloadState, Never> {
        MLXDownloadManager.shared.downloadStatePublisher
    }

    var modelCacheDirectoryURL: URL {
        MLXDownloadManager.shared.modelCacheDirectoryURL
    }

    func download(modelID: String) async {
        await MLXDownloadManager.shared.download(modelID: modelID)
    }

    func pauseDownload() {
        MLXDownloadManager.shared.pause()
    }

    func resumeDownload() async {
        await MLXDownloadManager.shared.resume()
    }

    func cancelDownload() {
        MLXDownloadManager.shared.cancel()
    }

    func deleteDownloadedModel(modelID: String) throws {
        try MLXDownloadManager.shared.deleteDownloadedModel(modelID: modelID)
    }

    func setDownloadSpeedLimit(bytesPerSecond: Int?) {
        MLXDownloadManager.shared.updateDownloadSpeed(bytesPerSecond: bytesPerSecond)
    }

    func refreshDownloadState() {
        MLXDownloadManager.shared.refreshDownloadState()
    }
}
