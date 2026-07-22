import Foundation
import HttpKit
import LLMKit
import LumiLLMProviderSupport
import LumiKernel
import LumiKernel
import LumiKernel
import SuperLogKit

public final class FreeModelProvider: LumiLLMProvider, SuperLog, @unchecked Sendable {
    enum Endpoints {
        static let openAIPrimary = "https://api.freemodel.dev/v1/chat/completions"
        static let openAIFallback = "https://vip-sg.freemodel.dev/v1/chat/completions"
        static let claudeT0 = "https://cc.freemodel.dev/v1/messages"
        static let claudeT1 = "https://api-cc.freemodel.dev/v1/messages"
    }

    /// Controls whether diagnostic logs are emitted (set to `true` for debugging)
    static let verbose = FreeModelDiagnosticLog.verbose

    static let claudeT1Models: Set<String> = [
        "claude-opus-4-8",
        "claude-opus-4-7",
        "claude-fable-5",
    ]

    static let claudeModels: Set<String> = [
        "claude-fable-5",
        "claude-opus-4-8",
        "claude-opus-4-7",
        "claude-opus-4-6",
        "claude-sonnet-4-6",
        "claude-haiku-4-5-20251001",
    ]

    static let gptModels: [String] = [
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.3-codex",
    ]

    public static let providerInfo = LumiLLMProviderInfo(
        id: "freemodel",
        displayName: LumiPluginLocalization.string("FreeModel", bundle: .module),
        description: LumiPluginLocalization.string("Free LLM Gateway by freemodel.dev", bundle: .module),
        defaultModel: "gpt-5.4",
        availableModels: gptModels + claudeModels.sorted(),
        contextWindowSizes: [
            "gpt-5.5": 1_000_000,
            "gpt-5.4": 1_000_000,
            "gpt-5.4-mini": 400_000,
            "gpt-5.3-codex": 400_000,
            "claude-fable-5": 200_000,
            "claude-opus-4-8": 200_000,
            "claude-opus-4-7": 200_000,
            "claude-opus-4-6": 200_000,
            "claude-sonnet-4-6": 200_000,
            "claude-haiku-4-5-20251001": 200_000,
        ],
        modelCapabilities: [
            "gpt-5.5": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
            "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true),
            "claude-fable-5": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-8": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-7": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-6": .init(supportsVision: true, supportsTools: true),
            "claude-sonnet-4-6": .init(supportsVision: true, supportsTools: true),
            "claude-haiku-4-5-20251001": .init(supportsVision: true, supportsTools: true),
        ],
        websiteURL: URL(string: "https://freemodel.dev/")!
    ,
            apiKeyStorageKey: "DevAssistant_ApiKey_FreeModel"
        )

    public static var info: LumiLLMProviderInfo { providerInfo }

    private let openAIBackend: FreeModelOpenAIBackend
    private let claudeT0Backend: FreeModelClaudeBackend
    private let claudeT1Backend: FreeModelClaudeBackend

    public init() {
        openAIBackend = FreeModelOpenAIBackend()
        claudeT0Backend = FreeModelClaudeBackend(
            nodeLabel: "claude-t0",
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: Endpoints.claudeT0,
                fallbackBaseURLs: [Endpoints.claudeT1]
            )
        )
        claudeT1Backend = FreeModelClaudeBackend(
            nodeLabel: "claude-t1",
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: Endpoints.claudeT1,
                fallbackBaseURLs: [Endpoints.claudeT0]
            )
        )
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let backend = backendSelection(for: request.model)
        if Self.verbose {
            FreeModelDiagnosticLog.logger.info("\(FreeModelDiagnosticLog.t)send model=\(request.model) route=\(backend.label)")
        }
        let message = try await backend.provider.send(request)
        return try await fallbackIfGatewayRejected(
            message,
            request: request,
            backendLabel: backend.label
        )
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let backend = backendSelection(for: request.model)
        if Self.verbose {
            FreeModelDiagnosticLog.logger.info("\(FreeModelDiagnosticLog.t)stream start model=\(request.model) route=\(backend.label) messages=\(request.messages.count) tools=\(request.tools.count)")
        }

        let message: LumiChatMessage
        if backend.label.hasPrefix("anthropic") {
            message = try await streamAnthropicWithRejectionGuard(
                backend: backend,
                request: request,
                onChunk: onChunk
            )
        } else {
            message = try await streamWithLogging(
                backend: backend,
                request: request,
                onChunk: onChunk
            )
        }

        if backend.label.hasPrefix("anthropic"),
           FreeModelClaudeCodeEmulation.isGatewayRejection(message.content) {
            if Self.verbose {
                FreeModelDiagnosticLog.logger.info("\(FreeModelDiagnosticLog.t)anthropic gateway rejected CLI mimic, falling back to openai/claude")
            }
            return try await streamWithLogging(
                backend: BackendSelection(label: "openai/claude-fallback", provider: openAIBackend),
                request: request,
                onChunk: onChunk
            )
        }
        return message
    }

    private func streamAnthropicWithRejectionGuard(
        backend: BackendSelection,
        request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let gate = GatewayRejectionGate()
        return try await streamWithLogging(backend: backend, request: request) { chunk in
            if await gate.shouldSuppress(chunk: chunk) {
                return
            }
            await onChunk(chunk)
        }
    }

    private func fallbackIfGatewayRejected(
        _ message: LumiChatMessage,
        request: LumiLLMRequest,
        backendLabel: String
    ) async throws -> LumiChatMessage {
        guard backendLabel.hasPrefix("anthropic"),
              FreeModelClaudeCodeEmulation.isGatewayRejection(message.content)
        else {
            return message
        }
        if Self.verbose {
            FreeModelDiagnosticLog.logger.info("\(FreeModelDiagnosticLog.t)anthropic gateway rejected CLI mimic, falling back to openai/claude")
        }
        return try await openAIBackend.send(request)
    }

    private func streamWithLogging(
        backend: BackendSelection,
        request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let chunkCounter = ChunkCounter()
        do {
            let message = try await backend.provider.sendStreaming(request) { chunk in
                let index = chunkCounter.next()
                let contentLen = chunk.content?.count ?? 0
                if index <= 5 || chunk.isDone || contentLen > 0 {
                    if Self.verbose {
                        FreeModelDiagnosticLog.logger.info(
                            "\(FreeModelDiagnosticLog.t)chunk #\(index) route=\(backend.label) contentLen=\(contentLen) isDone=\(chunk.isDone) isThinking=\(chunk.isThinking)"
                        )
                    }
                }
                await onChunk(chunk)
            }
            if Self.verbose {
                FreeModelDiagnosticLog.logger.info(
                    "\(FreeModelDiagnosticLog.t)stream done route=\(backend.label) model=\(request.model) contentLen=\(message.content.count) preview=\(message.content.prefix(120))"
                )
                if message.content.isEmpty {
                    FreeModelDiagnosticLog.logger.info(
                        "\(FreeModelDiagnosticLog.t)WARN empty content route=\(backend.label) model=\(request.model)"
                    )
                }
            }
            return message
        } catch {
            if Self.verbose {
                FreeModelDiagnosticLog.logger.info(
                    "\(FreeModelDiagnosticLog.t)stream error route=\(backend.label) model=\(request.model): \(error.localizedDescription)"
                )
            }
            throw error
        }
    }

    private func backendSelection(for model: String) -> BackendSelection {
        if Self.claudeT1Models.contains(model) {
            return BackendSelection(label: "anthropic/claude-t1", provider: claudeT1Backend)
        }
        if Self.claudeModels.contains(model) {
            return BackendSelection(label: "anthropic/claude-t0", provider: claudeT0Backend)
        }
        if model.hasPrefix("claude-") {
            if Self.verbose {
                FreeModelDiagnosticLog.logger.info(
                    "\(FreeModelDiagnosticLog.t)WARN model=\(model) is not in Claude catalog, falling back to openai endpoint"
                )
            }
            return BackendSelection(label: "openai/claude", provider: openAIBackend)
        }
        return BackendSelection(label: "openai", provider: openAIBackend)
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await backendSelection(for: model).provider.checkAvailability(model: model)
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(storageKey: Self.info._apiKeyStorageKey, displayName: Self.info.displayName)
    }

    public func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }

    public func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }

    public func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }

    public func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }

    public func errorRenderKind(for error: Error) -> String? {
        nil
    }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: Self.info.id,
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: errorRenderKind(for: error)
        )
    }
}

struct BackendSelection {
    let label: String
    let provider: any LumiLLMProvider
}
