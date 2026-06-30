import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport
import SuperLogKit
import os

public final class SublyxProvider: OpenAICompatibleLumiProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "📡"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.sublyx")

    public static let apiKeyHelpURL: String? = "https://api.sublyx.org/"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "sublyx",
            displayName: LumiPluginLocalization.string("Sublyx", bundle: .module),
            description: LumiPluginLocalization.string("GPT API Gateway by Sublyx", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
                "gpt-5.5",
                "gpt-5.4",
                "gpt-5.4-mini",
                "gpt-4o",
                "gpt-4.1"
            ],
            contextWindowSizes: [
                "gpt-5.5": 1_000_000,
                "gpt-5.4": 1_000_000,
                "gpt-5.4-mini": 1_000_000,
                "gpt-4o": 128_000,
                "gpt-4.1": 1_000_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-4o": .init(supportsVision: true, supportsTools: true),
                "gpt-4.1": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://api.sublyx.org/")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Sublyx"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.sublyx.org/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: true,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return SublyxRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return SublyxRenderKind.http(statusCode)
        }

        return SublyxRenderKind.requestFailed
    }

    // MARK: - API Key

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(
            providerID: Self.info.id,
            displayName: Self.info.displayName,
            isLocal: Self.info.isLocal
        )
    }

    // MARK: - SuperLog

    public override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        do {
            let message = try await super.sendStreaming(request, onChunk: onChunk)
            return message
        } catch {
            // 捕获错误，检查是否为 HTTP 错误
            if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error),
               !(200..<300).contains(statusCode) {
                // 输出非 2xx 状态码时的响应内容
                Self.logger.error("\(Self.t)HTTP \(statusCode) 错误响应: \(error.localizedDescription)")
            }
            throw error
        }
    }
}
