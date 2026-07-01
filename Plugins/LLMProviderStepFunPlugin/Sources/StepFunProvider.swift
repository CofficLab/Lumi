import Foundation
import LumiCoreKit
import LumiLLMProviderSupport
import os
import SuperLogKit

public final class StepFunProvider: OpenAICompatibleLumiProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🌟"
    nonisolated static let verbose: Int = 3
    public static let shortName = "StepFun StepPlan"

    override public class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "stepfun",
            displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
            description: LumiPluginLocalization.string("StepFun StepPlan AI", bundle: .module),
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
                "step-3.5-flash",
            ],
            contextWindowSizes: [
                "step-3.7-flash": 262144,
                "step-router-v1": 262144,
                "stepaudio-2.5-chat": 1000000,
                "stepaudio-2.5-tts": 1000000,
                "stepaudio-2.5-asr": 1000000,
                "stepaudio-2.5-realtime": 1000000,
                "step-image-edit-2": 1000000,
                "step-3.5-flash-2603": 262144,
                "step-3.5-flash": 262144,
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
                "step-3.5-flash": .init(supportsVision: true, supportsTools: true),
            ],
            websiteURL: URL(string: "https://www.stepfun.com/")!
        )
    }

    override public class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_StepFun"
    }

    public static let apiKeyHelpURL: String? = "https://www.stepfun.com/#/api"

    override public func logRawStreamChunk(_ data: Data) {
        guard Self.verbose >= 3, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        StepFunPlugin.logger.info("\(Self.t)raw chunk: \(text)")
    }

    public init() {
        let config = LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.stepfun.com/step_plan/v1/chat/completions",
            additionalHeaders: ["Accept": "text/event-stream"],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false,
            includesReasoningContentInMessages: true
        )
        if Self.verbose > 0 {
            StepFunPlugin.logger.info("\(Self.t)初始化配置完成 baseURL=\(config.baseURL)")
        }
        super.init(configuration: config)
    }

    override public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        if Self.verbose > 0 {
            StepFunPlugin.logger.info("\(Self.t)开始流式请求 model=\(request.model), messagesCount=\(request.messages.count)")
        }

        final class AccumulatedState: @unchecked Sendable {
            var value = ""
        }
        let accumulated = AccumulatedState()
        let wrappedChunk: @Sendable (LumiStreamChunk) async -> Void = { chunk in
            if let content = chunk.content, !content.isEmpty {
                accumulated.value += content
            }

            if chunk.isDone {
                StepFunPlugin.logger.info("\(Self.t)chunk 完成 contentLength=\(accumulated.value.count)")
            }
            await onChunk(chunk)
        }

        do {
            let result = try await super.sendStreaming(request, onChunk: wrappedChunk)
            if Self.verbose > 0 {
                StepFunPlugin.logger.info("\(self.t)流式请求成功 finalContentLength=\(result.content.count), toolCallsCount=\(result.toolCalls?.count ?? 0)")
            }

            // 检测空响应：API 返回了成功状态但没有实际内容，主动抛出错误以触发重试
            if result.content.isEmpty, result.toolCalls == nil, result.reasoningContent == nil || result.reasoningContent!.isEmpty {
                StepFunPlugin.logger.warning("\(self.t)检测到空响应，promptTokens=\(result.metadata["inputTokens"] ?? "0")，主动抛出错误以触发重试")
                throw LumiLLMProviderSupportError.emptyResponse
            }

            return result
        } catch let supportError as LumiLLMProviderSupportError {
            // LumiLLMProviderSupportError 类型的错误直接抛出，由上层重试机制处理
            throw supportError
        } catch {
            if !accumulated.value.isEmpty {
                StepFunPlugin.logger.info("\(self.t)流式输出已产生内容：\n\(accumulated.value)")
            }
            if Self.verbose > 0 {
                StepFunPlugin.logger.error("\(self.t)流式请求失败：\(error.localizedDescription)")
            }
            throw error
        }
    }

    override public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    override public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }

    // MARK: - Error Rendering

    override public func errorRenderKind(for error: Error) -> String? {
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
