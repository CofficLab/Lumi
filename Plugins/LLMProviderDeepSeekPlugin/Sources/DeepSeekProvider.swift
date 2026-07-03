import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class DeepSeekProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "deepseek",
            displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
            description: LumiPluginLocalization.string("DeepSeek AI", bundle: .module),
            defaultModel: "deepseek-chat",
            availableModels: [
                "deepseek-chat",
                "deepseek-coder"
            ],
            contextWindowSizes: [
                "deepseek-chat": 1_000_000,
                "deepseek-coder": 1_000_000
            ],
            modelCapabilities: [
                "deepseek-chat": .init(supportsVision: false, supportsTools: true),
                "deepseek-coder": .init(supportsVision: false, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.deepseek.com/")!
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
                baseURL: "https://api.deepseek.com/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: false,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }
}
