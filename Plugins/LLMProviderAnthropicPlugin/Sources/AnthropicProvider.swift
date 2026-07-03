import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class AnthropicProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_Anthropic"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "anthropic",
            displayName: LumiPluginLocalization.string("Anthropic", bundle: .module),
            description: LumiPluginLocalization.string("Claude AI by Anthropic", bundle: .module),
            defaultModel: "claude-sonnet-4-20250514",
            availableModels: [
            "claude-sonnet-4-20250514",
            "claude-opus-4-20250514",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-sonnet-20240620",
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307"
            ],
            contextWindowSizes: [
                "claude-sonnet-4-20250514": 200_000,
                "claude-opus-4-20250514": 200_000,
                "claude-3-5-sonnet-20241022": 200_000,
                "claude-3-5-sonnet-20240620": 200_000,
                "claude-3-opus-20240229": 200_000,
                "claude-3-sonnet-20240229": 200_000,
                "claude-3-haiku-20240307": 200_000
            ],
            modelCapabilities: [
                "claude-sonnet-4-20250514": .init(supportsVision: true, supportsTools: true),
                "claude-opus-4-20250514": .init(supportsVision: true, supportsTools: true),
                "claude-3-5-sonnet-20241022": .init(supportsVision: true, supportsTools: true),
                "claude-3-5-sonnet-20240620": .init(supportsVision: true, supportsTools: true),
                "claude-3-opus-20240229": .init(supportsVision: true, supportsTools: true),
                "claude-3-sonnet-20240229": .init(supportsVision: true, supportsTools: true),
                "claude-3-haiku-20240307": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.anthropic.com/")!
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
            configuration: LumiAnthropicCompatibleProviderConfiguration(baseURL: "https://api.anthropic.com/v1/messages")
        )
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }
}
