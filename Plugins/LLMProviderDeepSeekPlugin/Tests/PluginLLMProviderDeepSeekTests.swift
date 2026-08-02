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
}
