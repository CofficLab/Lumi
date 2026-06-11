import LumiCoreKit
import LumiLLMProviderSupport

public enum XiaomiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xiaomi",
        displayName: String(localized: "Xiaomi", bundle: .module),
        description: String(localized: "Contributes Xiaomi models to Lumi Chat.", bundle: .module),
        order: 102
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [XiaomiProvider()]
    }
}

public final class XiaomiProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "xiaomi",
            displayName: String(localized: "Xiaomi", bundle: .module),
            description: String(localized: "Xiaomi AI Models", bundle: .module),
            defaultModel: "mimo-v2.5-pro",
            availableModels: [
            "mimo-v2.5-pro",
            "mimo-v2.5",
            "mimo-v2-pro",
            "mimo-v2-omni",
            "mimo-v2.5-tts",
            "mimo-v2.5-tts-voiceclone",
            "mimo-v2.5-tts-voicedesign",
            "mimo-v2-tts"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Xiaomi"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://token-plan-cn.xiaomimimo.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
