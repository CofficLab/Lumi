import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class AliyunTokenPlanProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    public static let shortName = "Aliyun"
    public static let apiKeyHelpURL: String? = "https://help.aliyun.com/zh/model-studio/get-api-key"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "aliyun-tokenplan",
            displayName: LumiPluginLocalization.string("阿里云 TokenPlan", bundle: .module),
            description: LumiPluginLocalization.string("阿里云 DashScope Token Plan", bundle: .module),
            defaultModel: "qwen3.6-plus",
            availableModels: [
                "qwen3.6-flash",
                "qwen3.6-plus",
                "qwen3.7-plus",
                "qwen3.7-max",
                "qwen-image-2.0",
                "qwen-image-2.0-pro",
                "wan2.7-image",
                "wan2.7-image-pro",
                "deepseek-v3.2",
                "deepseek-v4-flash",
                "deepseek-v4-pro",
                "kimi-k2.5",
                "kimi-k2.6",
                "kimi-k2.7-code",
                "glm-5",
                "glm-5.1",
                "glm-5.2",
                "MiniMax-M2.5",
            ],
            contextWindowSizes: [
                "qwen3.6-flash": 1_000_000,
                "qwen3.6-plus": 1_000_000,
                "qwen3.7-plus": 1_000_000,
                "qwen3.7-max": 1_000_000,
                "qwen-image-2.0": 32_768,
                "qwen-image-2.0-pro": 32_768,
                "wan2.7-image": 32_768,
                "wan2.7-image-pro": 32_768,
                "deepseek-v3.2": 131_072,
                "deepseek-v4-flash": 131_072,
                "deepseek-v4-pro": 131_072,
                "kimi-k2.5": 262_144,
                "kimi-k2.6": 262_144,
                "kimi-k2.7-code": 262_144,
                "glm-5": 1_000_000,
                "glm-5.1": 1_000_000,
                "glm-5.2": 1_000_000,
                "MiniMax-M2.5": 204_800
            ],
            modelCapabilities: [
                "qwen3.6-flash": .init(supportsVision: true, supportsTools: true),
                "qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.7-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.7-max": .init(supportsVision: false, supportsTools: true),
                "qwen-image-2.0": .init(supportsVision: true, supportsTools: false),
                "qwen-image-2.0-pro": .init(supportsVision: true, supportsTools: false),
                "wan2.7-image": .init(supportsVision: false, supportsTools: false),
                "wan2.7-image-pro": .init(supportsVision: false, supportsTools: false),
                "deepseek-v3.2": .init(supportsVision: false, supportsTools: true),
                "deepseek-v4-flash": .init(supportsVision: true, supportsTools: true),
                "deepseek-v4-pro": .init(supportsVision: true, supportsTools: true),
                "kimi-k2.5": .init(supportsVision: false, supportsTools: true),
                "kimi-k2.6": .init(supportsVision: true, supportsTools: true),
                "kimi-k2.7-code": .init(supportsVision: true, supportsTools: true),
                "glm-5": .init(supportsVision: true, supportsTools: true),
                "glm-5.1": .init(supportsVision: true, supportsTools: true),
                "glm-5.2": .init(supportsVision: true, supportsTools: true),
                "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!
        )
    }

    // 与 CodingPlan 共享同一个 API Key
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_Aliyun"

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://token-plan.cn-beijing.maas.aliyuncs.com/apps/anthropic/v1/messages"
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

    override public func lumiResolveAPIKey() throws -> String {
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }
}
