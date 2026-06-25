import Foundation
import LumiCoreKit
import LumiLLMProviderSupport
import os

public enum FreeModelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.freemodel",
        displayName: LumiPluginLocalization.string("FreeModel", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FreeModel models to Lumi Chat.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FreeModelProvider()]
    }
}

public final class FreeModelProvider: LumiLLMProvider, @unchecked Sendable {
    enum Endpoints {
        static let openAIPrimary = "https://api.freemodel.dev/v1/chat/completions"
        static let openAIFallback = "https://vip-sg.freemodel.dev/v1/chat/completions"
        static let claudeT0 = "https://cc.freemodel.dev/v1/messages"
        static let claudeT1 = "https://api-cc.freemodel.dev/v1/messages"
    }

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
    )

    public static var info: LumiLLMProviderInfo { providerInfo }

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_FreeModel"

    private let openAIBackend: FreeModelOpenAIBackend
    private let claudeT0Backend: FreeModelClaudeBackend
    private let claudeT1Backend: FreeModelClaudeBackend

    public init() {
        openAIBackend = FreeModelOpenAIBackend()
        claudeT0Backend = FreeModelClaudeBackend(
            nodeLabel: "claude-t0",
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: Endpoints.claudeT0,
                fallbackBaseURLs: [Endpoints.claudeT1]
            )
        )
        claudeT1Backend = FreeModelClaudeBackend(
            nodeLabel: "claude-t1",
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: Endpoints.claudeT1,
                fallbackBaseURLs: [Endpoints.claudeT0]
            )
        )
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let backend = backendSelection(for: request.model)
        FreeModelDiagnosticLog.log("send model=\(request.model) route=\(backend.label)")
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
        FreeModelDiagnosticLog.log(
            "stream start model=\(request.model) route=\(backend.label) messages=\(request.messages.count) tools=\(request.tools.count)"
        )

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
            FreeModelDiagnosticLog.log(
                "anthropic gateway rejected CLI mimic, falling back to openai/claude"
            )
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
        FreeModelDiagnosticLog.log("anthropic gateway rejected CLI mimic, falling back to openai/claude")
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
                    FreeModelDiagnosticLog.log(
                        "chunk #\(index) route=\(backend.label) contentLen=\(contentLen) isDone=\(chunk.isDone) isThinking=\(chunk.isThinking)"
                    )
                }
                await onChunk(chunk)
            }
            FreeModelDiagnosticLog.log(
                "stream done route=\(backend.label) model=\(request.model) contentLen=\(message.content.count) preview=\(message.content.prefix(120))"
            )
            if message.content.isEmpty {
                FreeModelDiagnosticLog.log(
                    "WARN empty content route=\(backend.label) model=\(request.model)"
                )
            }
            return message
        } catch {
            FreeModelDiagnosticLog.log(
                "stream error route=\(backend.label) model=\(request.model): \(error.localizedDescription)"
            )
            throw error
        }
    }

    private struct BackendSelection {
        let label: String
        let provider: any LumiLLMProvider
    }

    private func backendSelection(for model: String) -> BackendSelection {
        if Self.claudeT1Models.contains(model) {
            return BackendSelection(label: "anthropic/claude-t1", provider: claudeT1Backend)
        }
        if Self.claudeModels.contains(model) {
            return BackendSelection(label: "anthropic/claude-t0", provider: claudeT0Backend)
        }
        if model.hasPrefix("claude-") {
            FreeModelDiagnosticLog.log(
                "WARN model=\(model) is not in Claude catalog, falling back to openai endpoint"
            )
            return BackendSelection(label: "openai/claude", provider: openAIBackend)
        }
        return BackendSelection(label: "openai", provider: openAIBackend)
    }
}

// MARK: - Backends

private final class FreeModelOpenAIBackend: OpenAICompatibleLumiProvider, @unchecked Sendable {
    override class var info: LumiLLMProviderInfo { FreeModelProvider.providerInfo }
    override class var apiKeyStorageKey: String { FreeModelProvider.apiKeyStorageKey }

    init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: FreeModelProvider.Endpoints.openAIPrimary,
                fallbackBaseURLs: [FreeModelProvider.Endpoints.openAIFallback],
                additionalHeaders: [:],
                includeUsageInStreamOptions: true,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }
}

private final class FreeModelClaudeBackend: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    private let nodeLabel: String
    private let pendingStreamingModel = OSAllocatedUnfairLock<String?>(initialState: nil)

    override class var info: LumiLLMProviderInfo { FreeModelProvider.providerInfo }
    override class var apiKeyStorageKey: String { FreeModelProvider.apiKeyStorageKey }

    init(nodeLabel: String, configuration: LumiAnthropicCompatibleProviderConfiguration) {
        self.nodeLabel = nodeLabel
        super.init(configuration: configuration)
    }

    override func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("cli", forHTTPHeaderField: "x-app")
        request.addValue(FreeModelClaudeCodeEmulation.userAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue(FreeModelClaudeCodeEmulation.sessionID, forHTTPHeaderField: "X-Claude-Code-Session-Id")

        if let model = pendingStreamingModel.withLock({ $0 }) {
            let betas = FreeModelClaudeCodeEmulation.anthropicBetaHeader(for: model)
            request.addValue(betas, forHTTPHeaderField: "anthropic-beta")
        }

        FreeModelDiagnosticLog.log(
            "anthropic request node=\(nodeLabel) url=\(url.absoluteString) ua=\(FreeModelClaudeCodeEmulation.userAgent()) session=\(FreeModelClaudeCodeEmulation.sessionID)"
        )
        return request
    }

    override func customizeAnthropicStreamingBody(
        _ body: inout [String: Any],
        request: LumiLLMRequest
    ) {
        pendingStreamingModel.withLock { $0 = request.model }

        let firstText = FreeModelClaudeCodeEmulation.firstUserMessageText(from: request.messages)
        let fingerprint = FreeModelClaudeCodeEmulation.computeFingerprint(firstUserMessageText: firstText)
        let systemParts = request.messages
            .filter { $0.role == .system }
            .map(\.content)
            .filter { !$0.isEmpty }

        body["system"] = FreeModelClaudeCodeEmulation.systemBlocks(
            fingerprint: fingerprint,
            existingSystemParts: systemParts
        )
        body["metadata"] = FreeModelClaudeCodeEmulation.metadata()

        FreeModelDiagnosticLog.log(
            "anthropic body node=\(nodeLabel) model=\(request.model) fingerprint=\(fingerprint) betas=\(FreeModelClaudeCodeEmulation.anthropicBetaHeader(for: request.model))"
        )
    }

    override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let message = try await super.sendStreaming(request, onChunk: onChunk)
        pendingStreamingModel.withLock { $0 = nil }
        return message
    }
}

private final class ChunkCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

private actor GatewayRejectionGate {
    private var buffered = ""
    private var suppressing = false

    func shouldSuppress(chunk: LumiStreamChunk) -> Bool {
        if suppressing {
            return true
        }
        if let content = chunk.content {
            buffered += content
            if FreeModelClaudeCodeEmulation.isGatewayRejection(buffered) {
                suppressing = true
                return true
            }
        }
        return false
    }
}
