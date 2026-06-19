import LumiCoreKit
import LumiLLMProviderSupport

public enum LPgptPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.lpgpt",
        displayName: LumiPluginLocalization.string("LPgpt", bundle: .module),
        description: LumiPluginLocalization.string("Contributes LPgpt models to Lumi Chat.", bundle: .module),
        order: 98
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [LPgptProvider()]
    }
}

public final class LPgptProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "lpgpt",
            displayName: LumiPluginLocalization.string("LPgpt", bundle: .module),
            description: LumiPluginLocalization.string("Free LLM Gateway by lpgpt.us", bundle: .module),
            defaultModel: "gpt-5.4",
            availableModels: [
            "gpt-5.4",
            "gpt-5.5"
            ],
            contextWindowSizes: [
                "gpt-5.4": 400_000,
                "gpt-5.5": 400_000
            ],
            modelCapabilities: [
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.5": .init(supportsVision: true, supportsTools: true)
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_LPgpt"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://lpgpt.us/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
