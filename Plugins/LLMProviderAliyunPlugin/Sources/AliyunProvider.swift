import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class AliyunProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    public static let shortName = "Aliyun"
    public static let apiKeyHelpURL: String? = "https://help.aliyun.com/zh/model-studio/get-api-key"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "aliyun",
            displayName: LumiPluginLocalization.string("阿里云 CodingPlan", bundle: .module),
            description: LumiPluginLocalization.string("阿里云 DashScope Coding Plan", bundle: .module),
            defaultModel: "qwen3.6-plus",
            availableModels: [
                "qwen3.7-plus",
                "qwen3.6-plus",
                "qwen3.5-plus",
                "qwen3-max-2026-01-23",
                "qwen3-coder-next",
                "qwen3-coder-plus",
                "kimi-k2.5",
                "glm-5",
                "glm-4.7",
                "MiniMax-M2.5",
            ],
            contextWindowSizes: [
                "qwen3.7-plus": 1_000_000,
                "qwen3.6-plus": 1_000_000,
                "qwen3.5-plus": 131_072,
                "qwen3-max-2026-01-23": 1_000_000,
                "qwen3-coder-next": 1_000_000,
                "qwen3-coder-plus": 1_000_000,
                "kimi-k2.5": 262_144,
                "glm-5": 1_000_000,
                "glm-4.7": 128_000,
                "MiniMax-M2.5": 204_800
            ],
            modelCapabilities: [
                "qwen3.7-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.5-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3-max-2026-01-23": .init(supportsVision: false, supportsTools: true),
                "qwen3-coder-next": .init(supportsVision: false, supportsTools: false),
                "qwen3-coder-plus": .init(supportsVision: false, supportsTools: false),
                "kimi-k2.5": .init(supportsVision: true, supportsTools: true),
                "glm-5": .init(supportsVision: false, supportsTools: true),
                "glm-4.7": .init(supportsVision: false, supportsTools: true),
                "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Aliyun"
    }

    public override class var environmentAPIKeyName: String? {
        "DASHSCOPE_API_KEY"
    }

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
            )
        )
    }

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return AliyunRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return AliyunRenderKind.http(statusCode)
        }

        return AliyunRenderKind.requestFailed
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
