import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public enum AnthropicPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.anthropic",
        displayName: LumiPluginLocalization.string("Anthropic", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Anthropic Claude models to Lumi Chat.", bundle: .module),
        order: 104
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AnthropicProvider()]
    }
}

public final class AnthropicProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
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

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Anthropic"
    }

    public override class var environmentAPIKeyName: String? {
        "ANTHROPIC_API_KEY"
    }

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(baseURL: "https://api.anthropic.com/v1/messages")
        )
    }
}
