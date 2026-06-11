import LumiCoreKit
import LumiLLMProviderSupport

public enum FlyMuxPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.flymux",
        displayName: LumiPluginLocalization.string("FlyMux", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FlyMux models to Lumi Chat.", bundle: .module),
        order: 94
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FlyMuxProvider()]
    }
}

public final class FlyMuxProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "flymux",
            displayName: LumiPluginLocalization.string("FlyMux", bundle: .module),
            description: LumiPluginLocalization.string("AI API Gateway by flymux.com", bundle: .module),
            defaultModel: "gpt-5.1-codex",
            availableModels: [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.4-openai-compact",
            "gpt-5.3",
            "gpt-5.3-codex",
            "gpt-5.2",
            "gpt-5.2-codex",
            "gpt-5.1",
            "gpt-5.1-codex",
            "gpt-5.1-codex-max",
            "gpt-5.1-codex-mini"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_FlyMux"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.flymux.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
