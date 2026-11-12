import Combine
import Foundation
import KitLLM

/// MLX 供应商的共用实现；具体供应商分别位于同目录的独立文件中。
@MainActor
class MLXProviderBase: SuperLLMProvider, LLMStreamingProviding {
    let providerInfo: LLMProviderInfo
    var providerID: String { providerInfo.id }

    init(providerID: String, displayName: String) {
        let models = MLXProviderCatalog.models(for: providerID)
        providerInfo = LLMProviderInfo(
            id: providerID,
            displayName: displayName,
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
        let response = try await streamComplete(request) { _ in }
        return Self.nonStreamingResponse(from: response)
    }

    /// 把流式响应收敛为非流式响应。
    ///
    /// 非流式调用（如上下文摘要）同样需要 token 用量与停止原因，
    /// 因此这里保留流式响应里的全部用量字段，而不是只取正文与工具调用。
    static func nonStreamingResponse(from response: LLMResponse) -> LLMResponse {
        LLMResponse(
            content: response.content,
            model: response.model,
            toolCalls: response.toolCalls,
            reasoningContent: response.reasoningContent,
            inputTokenCount: response.inputTokenCount,
            outputTokenCount: response.outputTokenCount,
            stopReason: response.stopReason
        )
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

extension MLXProviderBase: LLMModelDownloadProviding {
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
