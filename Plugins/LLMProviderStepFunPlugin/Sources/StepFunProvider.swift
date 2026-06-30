import Foundation
import os
import LumiCoreKit
import LumiLLMProviderSupport

public final class StepFunProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.stepfun")
    public static let shortName = "StepFun"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "stepfun",
            displayName: LumiPluginLocalization.string("StepFun", bundle: .module),
            description: LumiPluginLocalization.string("StepFun AI", bundle: .module),
            defaultModel: "step-3.5-flash",
            availableModels: [
                "step-3.7-flash",
                "step-router-v1",
                "stepaudio-2.5-chat",
                "stepaudio-2.5-tts",
                "stepaudio-2.5-asr",
                "stepaudio-2.5-realtime",
                "step-image-edit-2",
                "step-3.5-flash-2603",
                "step-3.5-flash"
            ],
            contextWindowSizes: [
                "step-3.7-flash": 1_000_000,
                "step-router-v1": 1_000_000,
                "stepaudio-2.5-chat": 1_000_000,
                "stepaudio-2.5-tts": 1_000_000,
                "stepaudio-2.5-asr": 1_000_000,
                "stepaudio-2.5-realtime": 1_000_000,
                "step-image-edit-2": 1_000_000,
                "step-3.5-flash-2603": 1_000_000,
                "step-3.5-flash": 1_000_000
            ],
            modelCapabilities: [
                "step-3.7-flash": .init(supportsVision: true, supportsTools: true),
                "step-router-v1": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-chat": .init(supportsVision: false, supportsTools: true),
                "stepaudio-2.5-tts": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-asr": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-realtime": .init(supportsVision: false, supportsTools: true),
                "step-image-edit-2": .init(supportsVision: true, supportsTools: false),
                "step-3.5-flash-2603": .init(supportsVision: true, supportsTools: true),
                "step-3.5-flash": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.stepfun.com/")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_StepFun"
    }

    /// 获取 API Key 的帮助链接
    public static let apiKeyHelpURL: String? = "https://www.stepfun.com/#/api"

    public init() {
        let config = LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.stepfun.com/step_plan/v1/chat/completions",
            additionalHeaders: ["Accept": "text/event-stream"],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false,
            includesReasoningContentInMessages: true
        )
        Self.logger.info("📝[init] ⚙️ baseURL=\(config.baseURL), acceptHeader=text/event-stream")
        super.init(configuration: config)
    }

    public override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        Self.logger.info("[sendStreaming] 🟢 start request model=\(request.model), messagesCount=\(request.messages.count)")
        
        let wrappedChunk: @Sendable (LumiStreamChunk) async -> Void = { chunk in
            if chunk.isDone {
                Self.logger.info("📝[sendStreaming] 🔵 chunk isDone")
            } else {
                let text = chunk.content ?? ""
                if !text.isEmpty {
                    Self.logger.info("📝[sendStreaming] 🟡 chunk contentLength=\(text.count), eventTitle=\(chunk.eventTitle ?? "-")")
                } else {
                    Self.logger.info("📝[sendStreaming] ⚪️ chunk EMPTY content, isThinking=\(chunk.isThinking), eventTitle=\(chunk.eventTitle ?? "-")")
                }
            }
            await onChunk(chunk)
        }
        
        do {
            let result = try await super.sendStreaming(request, onChunk: wrappedChunk)
            Self.logger.info("📝[sendStreaming] ✅ success finalContentLength=\(result.content.count), toolCallsCount=\(result.toolCalls?.count ?? 0)")
            return result
        } catch {
            Self.logger.error("📝[sendStreaming] ❌ error=\(error.localizedDescription)")
            throw error
        }
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

    // MARK: - Error Rendering

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return StepFunRenderKind.apiKeyMissing
        }
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return StepFunRenderKind.http(statusCode)
        }
        return StepFunRenderKind.requestFailed
    }

    // MARK: - API Key

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }
}
