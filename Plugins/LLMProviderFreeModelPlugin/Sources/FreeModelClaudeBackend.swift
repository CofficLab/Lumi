import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import os

final class FreeModelClaudeBackend: LumiLLMProvider, @unchecked Sendable {
    static let info = FreeModelProvider.providerInfo
    
    private let nodeLabel: String
    private let adapter: AnthropicCompatibleProviderAdapter
    private let apiService: LLMAPIService
    private let pendingStreamingModel = OSAllocatedUnfairLock<String?>(initialState: nil)
    
    init(
        nodeLabel: String,
        configuration: AnthropicCompatibleProviderConfiguration,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        self.nodeLabel = nodeLabel
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
        self.apiService = apiService
    }
    
    // MARK: - LumiLLMProvider Protocol
    
    func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(
            storageKey: Self.info._apiKeyStorageKey,
            displayName: Self.info.displayName
        )
    }
    
    func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }
    
    func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }
    
    func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }
    
    func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }
    
    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }
    
    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let message = try await LumiStreamingRequestSupport.sendAnthropicCompatibleStreaming(
            request,
            adapter: adapter,
            apiService: apiService,
            baseURLs: [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs,
            resolveAPIKey: lumiResolveAPIKey,
            buildRequest: { url, apiKey in
                buildRequest(url: url, apiKey: apiKey)
            },
            systemPrompt: "",
            customizeBody: { body, request in
                self.customizeAnthropicStreamingBody(&body, request: request)
            },
            onChunk: onChunk
        )
        pendingStreamingModel.withLock { $0 = nil }
        return message
    }
    
    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await LumiAnthropicCompatibleAvailability.chatPing(
            model: model,
            adapter: adapter,
            apiService: apiService,
            buildRequest: { url, apiKey in
                buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: lumiResolveAPIKey
        )
    }
    
    func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    func errorRenderKind(for error: Error) -> String? {
        nil
    }
    
    func makeErrorMessage(
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
    
    // MARK: - Custom Request Building
    
    private func buildRequest(url: URL, apiKey: String) -> URLRequest {
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
        
        if FreeModelProvider.verbose {
            let node = nodeLabel
            FreeModelDiagnosticLog.logger.info(
                "\(FreeModelDiagnosticLog.t)anthropic request node=\(node) url=\(url.absoluteString) ua=\(FreeModelClaudeCodeEmulation.userAgent()) session=\(FreeModelClaudeCodeEmulation.sessionID)"
            )
        }
        return request
    }
    
    private func customizeAnthropicStreamingBody(
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
        
        if FreeModelProvider.verbose {
            let node = nodeLabel
            FreeModelDiagnosticLog.logger.info(
                "\(FreeModelDiagnosticLog.t)anthropic body node=\(node) model=\(request.model) fingerprint=\(fingerprint) betas=\(FreeModelClaudeCodeEmulation.anthropicBetaHeader(for: request.model))"
            )
        }
    }
}