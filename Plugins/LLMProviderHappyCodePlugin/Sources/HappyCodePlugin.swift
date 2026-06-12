import LumiCoreKit
import LumiLLMProviderSupport

public enum HappyCodePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.happycode",
        displayName: LumiPluginLocalization.string("HappyCode", bundle: .module),
        description: LumiPluginLocalization.string("Contributes HappyCode models to Lumi Chat.", bundle: .module),
        order: 96
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [HappyCodeProvider()]
    }
}

public final class HappyCodeProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "happycode",
            displayName: LumiPluginLocalization.string("HappyCode", bundle: .module),
            description: LumiPluginLocalization.string("AI API Gateway by HappyCode", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
            "gpt-5.5"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_HappyCode"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://happycode.vip/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
