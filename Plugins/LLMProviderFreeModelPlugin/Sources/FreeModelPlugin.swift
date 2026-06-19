import LumiCoreKit
import LumiLLMProviderSupport

public enum FreeModelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.freemodel",
        displayName: LumiPluginLocalization.string("FreeModel", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FreeModel models to Lumi Chat.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FreeModelProvider()]
    }
}

public final class FreeModelProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "freemodel",
            displayName: LumiPluginLocalization.string("FreeModel", bundle: .module),
            description: LumiPluginLocalization.string("Free LLM Gateway by freemodel.dev", bundle: .module),
            defaultModel: "gpt-5.4",
            availableModels: [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3-codex"
            ],
            contextWindowSizes: [
                "gpt-5.5": 400_000,
                "gpt-5.4": 400_000,
                "gpt-5.4-mini": 400_000,
                "gpt-5.3-codex": 400_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true)
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_FreeModel"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.freemodel.dev/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
