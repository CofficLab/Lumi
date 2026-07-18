// MARK: - LLM Provider Plugins Imports
import Foundation
import LumiCoreKit
import LLMProviderAiRouterPlugin
import LLMProviderAliyunPlugin
import LLMProviderAnthropicPlugin
import LLMProviderCodexPlugin
import LLMProviderDeepSeekPlugin
import LLMProviderFeifeimiaoPlugin
import LLMProviderFlyMuxPlugin
import LLMProviderFreeModelPlugin
import LLMProviderHappyCodePlugin
import LLMProviderHyperAPIPlugin
// import LLMProviderKimiCodePlugin  // TODO: module dependency issue
import LLMProviderLPgptPlugin
import LLMProviderMiniMaxPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderMLXPlugin
import LLMProviderOpenAIPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderStepFunPlugin
import LLMProviderSublyxPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderZhipuPlugin

// MARK: - LLM Provider Plugins Extension

extension LumiPluginRegistry {
    /// LLM Provider 插件数组，包含所有大语言模型提供商插件。
    ///
    /// 包含：OpenAI、Zhipu、AiRouter、Aliyun、Anthropic、DeepSeek 等 20 个 provider
    public static let llmProviderPlugins: [any LumiPlugin.Type] = [
        // MARK: - Major Providers

        OpenAIPlugin.self,
        ZhipuPlugin.self,
        AiRouterPlugin.self,
        AliyunPlugin.self,
        AnthropicPlugin.self,
        DeepSeekPlugin.self,

        // MARK: - Other Providers

        // KimiCodePlugin.self,  // TODO: module dependency issue
        FeifeimiaoPlugin.self,
        FlyMuxPlugin.self,
        FreeModelPlugin.self,
        HappyCodePlugin.self,
        HyperAPIPlugin.self,
        LPgptPlugin.self,
        MegaLLMPlugin.self,
        MiniMaxPlugin.self,
        OpenRouterPlugin.self,
        XiaomiPlugin.self,
        XybbzPlugin.self,
        SublyxPlugin.self,
        StepFunPlugin.self,
        CodexLumiPlugin.self,
        MLXLumiPlugin.self,
    ]
}
