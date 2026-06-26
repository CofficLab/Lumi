import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

/// 小米 API（OpenAI 兼容协议）
///
/// 与 `XiaomiProvider`（TokenPlan 计费入口）同属小米 mimo 系列，但走标准的
/// OpenAI 兼容接口（`https://api.xiaomimimo.com/v1`），使用独立的 API Key 与计费。
/// 两者模型清单一致，方便用户在「按 Token 计费」与「标准 API」间切换。
public final class XiaomiAPIProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    /// 获取 API Key 的帮助页面（小米 MIMO 开放平台）。
    public static let apiKeyHelpURL: String? = "https://platform.xiaomimimo.com/"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "xiaomi-api",
            displayName: LumiPluginLocalization.string("Xiaomi API", bundle: .module),
            description: LumiPluginLocalization.string("Xiaomi API (OpenAI-compatible)", bundle: .module),
            defaultModel: "mimo-v2.5-pro",
            availableModels: [
                "mimo-v2.5-pro",
                "mimo-v2.5",
                "mimo-v2.5-tts",
                "mimo-v2.5-tts-voiceclone",
                "mimo-v2.5-tts-voicedesign"
            ],
            contextWindowSizes: [
                "mimo-v2.5-pro": 1_000_000,
                "mimo-v2.5": 1_000_000,
                "mimo-v2.5-tts": 131_072,
                "mimo-v2.5-tts-voiceclone": 131_072,
                "mimo-v2.5-tts-voicedesign": 131_072
            ],
            modelCapabilities: [
                "mimo-v2.5-pro": .init(supportsVision: true, supportsTools: true),
                "mimo-v2.5": .init(supportsVision: false, supportsTools: true),
                "mimo-v2.5-tts": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
                "mimo-v2.5-tts-voiceclone": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
                "mimo-v2.5-tts-voicedesign": .init(supportsVision: false, supportsTools: false, supportsTTS: true)
            ],
            websiteURL: URL(string: "https://www.mi.com")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_XiaomiAPI"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.xiaomimimo.com/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: false,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    // MARK: - Send（捕获错误并转换为可渲染的错误消息）

    public override func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let conversationID = request.messages.first?.conversationID ?? UUID()
        do {
            return try await super.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return XiaomiErrorHandling.errorMessage(
                providerID: Self.info.id,
                conversationID: conversationID,
                error: error
            )
        }
    }

    public override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let conversationID = request.messages.first?.conversationID ?? UUID()
        do {
            return try await super.sendStreaming(request, onChunk: onChunk)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return XiaomiErrorHandling.errorMessage(
                providerID: Self.info.id,
                conversationID: conversationID,
                error: error
            )
        }
    }

    // MARK: - API Key

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }
}
