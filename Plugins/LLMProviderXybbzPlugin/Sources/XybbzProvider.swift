import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class XybbzProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_Xybbz"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "xybbz",
            displayName: LumiPluginLocalization.string("Xybbz", bundle: .module),
            description: LumiPluginLocalization.string("AI API Gateway by xybbz", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
            "gpt-5.5",
            "gpt-5.4"
            ],
            contextWindowSizes: [
                "gpt-5.5": 1_000_000,
                "gpt-5.4": 1_000_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://xybbz.xyz")!
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
            baseURL: "https://sub2api.xybbz.xyz/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
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
