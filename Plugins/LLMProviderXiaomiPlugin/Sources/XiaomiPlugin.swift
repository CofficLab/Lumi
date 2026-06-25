import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public enum XiaomiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xiaomi",
        displayName: LumiPluginLocalization.string("Xiaomi", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Xiaomi models to Lumi Chat.", bundle: .module),
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
            displayName: LumiPluginLocalization.string("Xiaomi", bundle: .module),
            description: LumiPluginLocalization.string("Xiaomi AI Models", bundle: .module),
            defaultModel: "mimo-v2.5-pro",
            availableModels: [
            "mimo-v2.5-pro",
            "mimo-v2.5",
            "mimo-v2.5-tts",
            "mimo-v2.5-tts-voiceclone",
            "mimo-v2.5-tts-voicedesign"
            ],
            contextWindowSizes: [
                "mimo-v2.5-pro": 1_000_000,
                "mimo-v2.5": 1_000_000,
                "mimo-v2.5-tts": 131_072,
                "mimo-v2.5-tts-voiceclone": 131_072,
                "mimo-v2.5-tts-voicedesign": 131_072
            ],
            modelCapabilities: [
                "mimo-v2.5-pro": .init(supportsVision: true, supportsTools: true),
                "mimo-v2.5": .init(supportsVision: false, supportsTools: true),
                "mimo-v2.5-tts": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
                "mimo-v2.5-tts-voiceclone": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
                "mimo-v2.5-tts-voicedesign": .init(supportsVision: false, supportsTools: false, supportsTTS: true)
            ],
            websiteURL: URL(string: "https://www.mi.com")!
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
