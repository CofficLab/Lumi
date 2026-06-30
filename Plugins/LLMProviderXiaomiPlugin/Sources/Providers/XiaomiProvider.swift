import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class XiaomiProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    /// 获取 API Key 的帮助页面（小米 MIMO 开放平台）。
    public static let apiKeyHelpURL: String? = "https://platform.xiaomimimo.com/"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "xiaomi",
            displayName: LumiPluginLocalization.string("Xiaomi TokenPlan", bundle: .module),
            description: LumiPluginLocalization.string("Xiaomi TokenPlan AI Models", bundle: .module),
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
        "DevAssistant_ApiKey_Xiaomi"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://token-plan-cn.xiaomimimo.com/v1/chat/completions",
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
