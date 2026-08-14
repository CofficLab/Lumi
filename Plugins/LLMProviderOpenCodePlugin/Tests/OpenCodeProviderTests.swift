import Foundation
import Testing
@testable import LLMProviderOpenCodePlugin

// MARK: - tokenUsage 解析

@Suite("OpenCodeProvider tokenUsage 解析")
struct OpenCodeTokenUsageTests {
    /// OpenAI-compatible：prompt_tokens + prompt_cache_hit/miss
    @Test("OpenAI 格式：解析 prompt/completion/缓存命中")
    func parsesOpenAIUsage() throws {
        let json = """
        {
          "choices": [{"message": {"role": "assistant", "content": "hi"}}],
          "usage": {
            "prompt_tokens": 14534,
            "completion_tokens": 562,
            "prompt_cache_hit_tokens": 13952,
            "prompt_cache_miss_tokens": 582,
            "total_tokens": 15096
          }
        }
        """
        let usage = OpenCodeProvider().tokenUsage(from: Data(json.utf8))
        #expect(usage.inputTokens == 14534)
        #expect(usage.outputTokens == 562)
        #expect(usage.cachedInputTokens == 13952)
        #expect(usage.cacheWriteInputTokens == nil)
        #expect(usage.cacheTotalInputTokens == 14534) // hit + miss
    }

    /// OpenAI 格式走 prompt_tokens_details.cached_tokens（无 prompt_cache_hit_tokens 时兜底）
    @Test("OpenAI 格式：prompt_tokens_details.cached_tokens 兜底")
    func parsesOpenAIUsageDetailsFallback() throws {
        let json = """
        {
          "usage": {
            "prompt_tokens": 1000,
            "completion_tokens": 50,
            "prompt_tokens_details": {"cached_tokens": 900}
          }
        }
        """
        let usage = OpenCodeProvider().tokenUsage(from: Data(json.utf8))
        #expect(usage.inputTokens == 1000)
        #expect(usage.outputTokens == 50)
        #expect(usage.cachedInputTokens == 900)
        #expect(usage.cacheTotalInputTokens == 1000)
    }

    /// Anthropic 格式：input_tokens 不含缓存，total 须累加 cache_read + cache_write
    @Test("Anthropic 格式：input/output/cache_read/cache_write 累加")
    func parsesAnthropicUsage() throws {
        let json = """
        {
          "content": [{"type": "text", "text": "hi"}],
          "usage": {
            "input_tokens": 68,
            "output_tokens": 120,
            "cache_read_input_tokens": 512,
            "cache_creation_input_tokens": 10
          }
        }
        """
        let usage = OpenCodeProvider().tokenUsage(from: Data(json.utf8))
        #expect(usage.inputTokens == 68)
        #expect(usage.outputTokens == 120)
        #expect(usage.cachedInputTokens == 512)
        #expect(usage.cacheWriteInputTokens == 10)
        #expect(usage.cacheTotalInputTokens == 590) // 68 + 512 + 10
    }

    /// Responses API 格式：input_tokens 已含缓存命中，total 直接用 input
    @Test("Responses API 格式：input_tokens_details.cached_tokens")
    func parsesResponsesUsage() throws {
        let json = """
        {
          "output": [],
          "usage": {
            "input_tokens": 2095,
            "input_tokens_details": {"cached_tokens": 192},
            "output_tokens": 503,
            "output_tokens_details": {"reasoning_tokens": 0},
            "total_tokens": 2598
          }
        }
        """
        let usage = OpenCodeProvider().tokenUsage(from: Data(json.utf8))
        #expect(usage.inputTokens == 2095)
        #expect(usage.outputTokens == 503)
        #expect(usage.cachedInputTokens == 192)
        #expect(usage.cacheWriteInputTokens == nil)
        #expect(usage.cacheTotalInputTokens == 2095) // 已含缓存命中，不重复累加
    }

    /// 无 usage 字段时返回全空
    @Test("无 usage 字段：返回空统计")
    func returnsEmptyUsage() throws {
        let json = """
        {"choices": [{"message": {"role": "assistant", "content": "hi"}}]}
        """
        let usage = OpenCodeProvider().tokenUsage(from: Data(json.utf8))
        #expect(usage.inputTokens == nil)
        #expect(usage.outputTokens == nil)
        #expect(usage.cachedInputTokens == nil)
        #expect(usage.cacheTotalInputTokens == nil)
    }
}
