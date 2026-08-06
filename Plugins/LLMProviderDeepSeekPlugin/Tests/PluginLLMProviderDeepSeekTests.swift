import Foundation
import Testing
import LumiKernel
@testable import LLMProviderDeepSeekPlugin

@MainActor
struct PluginLLMProviderDeepSeekTests {
    @Test func pluginMetadata() {
        let plugin = DeepSeekPlugin()
        #expect(plugin.id.isEmpty == false)
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.category == .llmProvider)
        #expect(plugin.llmProviders(kernel: LumiKernel()).first is DeepSeekOpenAIProvider)
    }

    @Test func providerMetadata() {
        #expect(DeepSeekOpenAIProvider.info.id.isEmpty == false)
        #expect(DeepSeekOpenAIProvider.info.displayName.isEmpty == false)
        #expect(DeepSeekOpenAIProvider.info.defaultModel.isEmpty == false)
    }

    @Test func parsesDeepSeekCacheUsage() {
        let events = DeepSeekEventParser.parse(Data(
            #"data: {"usage":{"prompt_cache_hit_tokens":30,"prompt_cache_miss_tokens":12,"completion_tokens":11}}"#.utf8
        ))

        #expect(events.count == 1)
        #expect(events[0].cacheHitTokens == 30)
        #expect(events[0].cacheTotalInputTokens == 42)
        #expect(events[0].outputTokens == 11)
    }

    @Test func anthropicUsageTotalIncludesCacheRead() {
        // 实测(2026-08-06):DeepSeek Anthropic 端点的 input_tokens 是「未命中」部分,
        // 缓存率分母必须 = input_tokens + cache_read_input_tokens。
        // 例:总输入 580 = input_tokens(68) + cache_read(512)。
        let conversation = UUID()
        var message = DeepSeekChatMessage.assembling(
            conversationID: conversation,
            providerID: "deepseek-anthropic",
            modelName: "deepseek-v4-flash"
        )
        message.mergeUsage(DeepSeekAnthropicUsage(
            inputTokens: 68,
            outputTokens: 14,
            cacheReadInputTokens: 512,
            cacheCreationInputTokens: 0
        ))
        #expect(message.inputTokenCount == 68)
        #expect(message.cachedInputTokens == 512)
        #expect(message.cacheTotalInputTokens == 580)
    }
}
