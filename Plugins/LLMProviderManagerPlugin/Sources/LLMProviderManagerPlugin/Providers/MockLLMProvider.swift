import Foundation
import LumiCoreLLMProvider
import LumiCoreMessage
import SuperLogKit
import os

/// Mock `LumiLLMProvider` implementation.
///
/// Local, no network, no API key. Echoes the last user message back
/// as the assistant reply, with a small `[mock]` suffix. Streams the
/// reply in fixed-size chunks to exercise the streaming path used by
/// `MessageSendManager` (once the real LLM call is wired in).
///
/// Models:
/// - `mock-default` — text only, no tools, no vision.
///
/// This is a placeholder used to validate the registration pipeline
/// (`LLMProviderManagerPlugin.register` → `LLMProviderManager`) and
/// to give downstream code a working provider before real providers
/// (Anthropic, OpenAI, ...) are wired in.
public final class MockLLMProvider: LumiLLMProvider, @unchecked Sendable, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager.mock")
    public nonisolated static let emoji = "🧪"
    nonisolated static let verbose = true

    public static let info = LumiLLMProviderInfo(
        id: "mock",
        displayName: "Mock Provider",
        description: "Local mock provider that echoes user input. No network, no API key.",
        defaultModel: "mock-default",
        availableModels: ["mock-default"],
        isLocal: true,
        contextWindowSizes: [
            "mock-default": 8_192
        ],
        modelCapabilities: [
            "mock-default": .init(supportsVision: false, supportsTools: false, supportsTTS: false)
        ],
        websiteURL: URL(string: "https://example.invalid/mock-provider")!
    )

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MockLLMProvider")
        }
    }

    // MARK: - API Key (not needed for local mock)

    public func lumiResolveAPIKey() throws -> String {
        // Local mock never talks to a remote API.
        throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
    }

    public func hasApiKey() -> Bool { false }
    public func getApiKey() -> String { "" }
    public func setApiKey(_ apiKey: String) {}
    public func removeApiKey() {}

    // MARK: - Send / Stream

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let conversationID = request.messages.last?.conversationID ?? UUID()
        let reply = Self.composeReply(for: request)
        let chunkSize = 8
        var offset = reply.startIndex

        if Self.verbose {
            Self.logger.info("\(Self.t)sendStreaming ➡️ model=\(request.model), reply.len=\(reply.count)")
        }

        // Push the reply in small chunks so the streaming pipeline is exercised.
        while offset < reply.endIndex {
            let end = reply.index(offset, offsetBy: chunkSize, limitedBy: reply.endIndex) ?? reply.endIndex
            let piece = String(reply[offset..<end])
            await onChunk(
                LumiStreamChunk(
                    content: piece,
                    isDone: false,
                    isThinking: false,
                    eventTitle: "Mock thinking…"
                )
            )
            offset = end
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms between chunks
        }
        await onChunk(LumiStreamChunk(content: nil, isDone: true, eventTitle: "Mock done"))

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: reply,
            providerID: Self.info.id,
            modelName: request.model
        )
    }

    /// Compose a deterministic reply from the last user message.
    private static func composeReply(for request: LumiLLMRequest) -> String {
        let lastUser = request.messages.last(where: { $0.role == .user })?.content
            ?? request.messages.last?.content
            ?? ""
        let preview: String
        if lastUser.isEmpty {
            preview = "(no user input)"
        } else if lastUser.count <= 120 {
            preview = lastUser
        } else {
            preview = String(lastUser.prefix(120)) + "…"
        }
        return "(mock) \(preview) [mock]"
    }

    // MARK: - Availability / Status / Error

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        Self.info.availableModels.contains(model) ? .available
            : .unavailable(.unsupportedModel("Model '\(model)' is not provided by \(Self.info.displayName)"))
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        // Mock is fully local; no retry needed.
        .nonRetryable
    }

    public func errorRenderKind(for error: Error) -> String? { nil }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "Mock provider error: \(error.localizedDescription)",
            providerID: Self.info.id,
            modelName: request.model,
            isError: true
        )
    }
}
