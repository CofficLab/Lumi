import Foundation
import os
import LumiCoreKit
import LumiLLMProviderSupport

public final class StepFunProvider: OpenAICompatibleLumiProvider, SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌟"
    nonisolated static let verbose = false
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
                "step-3.7-flash": 262_144,
                "step-router-v1": 262_144,
                "stepaudio-2.5-chat": 1_000_000,
                "stepaudio-2.5-tts": 1_000_000,
                "stepaudio-2.5-asr": 1_000_000,
                "stepaudio-2.5-realtime": 1_000_000,
                "step-image-edit-2": 1_000_000,
                "step-3.5-flash-2603": 262_144,
                "step-3.5-flash": 262_144
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
        StepFunPlugin.logger.info("\(Self.t)初始化配置完成 baseURL=\(config.baseURL)")
        super.init(configuration: config)
    }

    public override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        StepFunPlugin.logger.info("\(Self.t)开始流式请求 model=\(request.model), messagesCount=\(request.messages.count)")

        let wrappedChunk: @Sendable (LumiStreamChunk) async -> Void = { chunk in
            if Self.verbose, chunk.isDone {
                StepFunPlugin.logger.info("\(Self.t)chunk 完成 contentLength=\(chunk.content?.count ?? 0)")
            }
            await onChunk(chunk)
        }

        do {
            let result = try await super.sendStreaming(request, onChunk: wrappedChunk)
            StepFunPlugin.logger.info("\(self.t)流式请求成功 finalContentLength=\(result.content.count), toolCallsCount=\(result.toolCalls?.count ?? 0)")
            return result
        } catch {
            StepFunPlugin.logger.error("\(self.t)流式请求失败：\(error.localizedDescription)")
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
