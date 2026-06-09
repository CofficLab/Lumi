import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public enum AliyunPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.aliyun",
        displayName: "阿里云 CodingPlan",
        description: "Contributes Aliyun CodingPlan models to Lumi Chat.",
        order: 105
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AliyunProvider()]
    }
}

public final class AliyunProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "aliyun",
            displayName: "阿里云 CodingPlan",
            description: "阿里云 DashScope Coding Plan",
            defaultModel: "qwen3.6-plus",
            availableModels: [
            "qwen3.5-plus",
            "qwen3.6-plus",
            "qwen3.7-max",
            "glm-4.7",
            "glm-5",
            "MiniMax-M2.5",
            "kimi-k2.5"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Aliyun"
    }

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
            )
        )
    }

    public override func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
}
