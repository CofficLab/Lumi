import Foundation
import LumiCoreKit
import LumiLLMProviderSupport
import os

final class FreeModelClaudeBackend: AnthropicCompatibleLumiProvider, @unchecked Sendable {
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

        if FreeModelProvider.verbose {
            let node = nodeLabel
            FreeModelDiagnosticLog.logger.info(
                "\(FreeModelDiagnosticLog.t)anthropic request node=\(node) url=\(url.absoluteString) ua=\(FreeModelClaudeCodeEmulation.userAgent()) session=\(FreeModelClaudeCodeEmulation.sessionID)"
            )
        }
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

        if FreeModelProvider.verbose {
            let node = nodeLabel
            FreeModelDiagnosticLog.logger.info(
                "\(FreeModelDiagnosticLog.t)anthropic body node=\(node) model=\(request.model) fingerprint=\(fingerprint) betas=\(FreeModelClaudeCodeEmulation.anthropicBetaHeader(for: request.model))"
            )
        }
    }

    override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let message = try await super.sendStreaming(request, onChunk: onChunk)
        pendingStreamingModel.withLock { $0 = nil }
        return message
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await checkAvailabilityUsingChatPing(model: model)
    }

    override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }

}
