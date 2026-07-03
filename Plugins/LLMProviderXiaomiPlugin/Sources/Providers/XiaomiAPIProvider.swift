import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

/// 小米 API（OpenAI 兼容协议）
///
/// 与 `XiaomiProvider`（TokenPlan 计费入口）同属小米 mimo 系列，但走标准的
/// OpenAI 兼容接口（`https://api.xiaomimimo.com/v1`），使用独立的 API Key 与计费。
/// 两者模型清单一致，方便用户在「按 Token 计费」与「标准 API」间切换。
public final class XiaomiAPIProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_XiaomiAPI"

    /// 获取 API Key 的帮助页面（小米 MIMO 开放平台）。
    public static let apiKeyHelpURL: String? = "https://platform.xiaomimimo.com/console/api-keys"

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

    override public func lumiResolveAPIKey() throws -> String {
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
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

    public override func errorRenderKind(for error: Error) -> String? {
        XiaomiErrorHandling.renderKind(for: error)
    }

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
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }
}
