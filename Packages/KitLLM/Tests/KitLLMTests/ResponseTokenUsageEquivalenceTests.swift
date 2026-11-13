import Foundation
import Testing
@testable import KitLLM

/// usage 归一化的**等价性**契约（Issue #1270）。
///
/// ## 为什么这样测
///
/// 修复把「读 usage」从「用 `JSONSerialization` 重解析整份响应」改成
/// 「随响应一起解码，再按别名规则归一」。归一规则必须与修复前**逐字
/// 相同**，否则 token 统计、缓存命中率会悄悄变化。
///
/// 因此这里保留一份**旧实现的等价物**（按旧代码的字典取值顺序逐条复刻）
/// 作为对照，对同一份 usage 断言两者完全相同。
@Suite("usage 归一化等价性")
struct ResponseTokenUsageEquivalenceTests {

    // MARK: - 旧实现的等价物（对照基准）

    /// 修复前 `VendorLLMProvider.tokenCounts(from:anthropic:)` 的等价实现。
    ///
    /// 逐字复刻旧代码的取值顺序与别名链。
    private static func legacyTokenCounts(
        usage: [String: Any]?,
        anthropic: Bool
    ) -> (input: Int?, output: Int?, cachedInput: Int?, cacheWrite: Int?, cacheTotal: Int?) {
        guard let usage else { return (nil, nil, nil, nil, nil) }

        let input: Int?
        let output: Int?
        if anthropic {
            input = usage["input_tokens"] as? Int
                ?? usage["prompt_tokens"] as? Int
                ?? usage["input_token_count"] as? Int
            output = usage["output_tokens"] as? Int
                ?? usage["completion_tokens"] as? Int
                ?? usage["output_token_count"] as? Int
        } else {
            input = usage["prompt_tokens"] as? Int
                ?? usage["input_tokens"] as? Int
                ?? usage["prompt_token_count"] as? Int
                ?? usage["input_token_count"] as? Int
            output = usage["completion_tokens"] as? Int
                ?? usage["output_tokens"] as? Int
                ?? usage["candidates_token_count"] as? Int
                ?? usage["output_token_count"] as? Int
        }

        let cachedInput = anthropic
            ? legacyAnthropicCacheRead(usage)
            : legacyOpenAICacheRead(usage)
        let cacheWrite = anthropic
            ? legacyAnthropicCacheWrite(usage)
            : legacyOpenAICacheWrite(usage)
        let cacheTotal = anthropic
            ? AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
                inputTokens: input,
                cachedInputTokens: cachedInput,
                cacheWriteInputTokens: cacheWrite
            )
            : input
        return (input, output, cachedInput, cacheWrite, cacheTotal)
    }

    private static func legacyOpenAICacheRead(_ usage: [String: Any]) -> Int? {
        usage["cached_tokens"] as? Int
            ?? (usage["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            ?? (usage["input_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            ?? usage["cache_read_input_tokens"] as? Int
            ?? usage["prompt_cache_hit_tokens"] as? Int
    }

    private static func legacyOpenAICacheWrite(_ usage: [String: Any]) -> Int? {
        usage["cache_write_tokens"] as? Int
            ?? usage["cache_creation_input_tokens"] as? Int
            ?? (usage["prompt_tokens_details"] as? [String: Any])?["cache_write_tokens"] as? Int
            ?? (usage["input_tokens_details"] as? [String: Any])?["cache_write_tokens"] as? Int
    }

    private static func legacyAnthropicCacheRead(_ usage: [String: Any]) -> Int? {
        usage["cache_read_input_tokens"] as? Int
            ?? usage["cached_tokens"] as? Int
            ?? (usage["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            ?? (usage["input_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
    }

    private static func legacyAnthropicCacheWrite(_ usage: [String: Any]) -> Int? {
        usage["cache_creation_input_tokens"] as? Int
            ?? usage["cache_write_tokens"] as? Int
            ?? (usage["prompt_tokens_details"] as? [String: Any])?["cache_creation_input_tokens"] as? Int
            ?? (usage["input_tokens_details"] as? [String: Any])?["cache_write_tokens"] as? Int
    }

    // MARK: - 对照工具

    /// 把任意 usage 字典编码成响应数据，再解码出新的 usage 类型。
    private func decodedUsage(
        _ usage: [String: Any],
        protocolName: String
    ) throws -> (any ResponseTokenUsage.UsageFields)? {
        // 两种协议的响应外壳不同：Anthropic 用 `content` 数组，
        // OpenAI 兼容协议用 `choices`。
        let payload: [String: Any]
        if protocolName == "anthropic" {
            payload = [
                "id": "msg-1",
                "content": [["type": "text", "text": "ok"]],
                "stop_reason": "end_turn",
                "usage": usage
            ]
        } else {
            payload = [
                "id": "resp-1",
                "choices": [[
                    "index": 0,
                    "message": ["role": "assistant", "content": "ok"],
                    "finish_reason": "stop"
                ]],
                "usage": usage
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        if protocolName == "anthropic" {
            let response = try JSONDecoder().decode(AnthropicCompatibleResponse.self, from: data)
            return response.usage
        }
        let response = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)
        return response.usage
    }

    /// 断言新旧两条路径对同一份 usage 给出完全相同的计数。
    private func assertEquivalent(
        _ usage: [String: Any],
        anthropic: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let legacy = Self.legacyTokenCounts(usage: usage, anthropic: anthropic)
        let decoded = try decodedUsage(usage, protocolName: anthropic ? "anthropic" : "openai")
        let current = ResponseTokenUsage.counts(from: decoded, anthropic: anthropic)

        #expect(current.input == legacy.input, "input 不一致", sourceLocation: sourceLocation)
        #expect(current.output == legacy.output, "output 不一致", sourceLocation: sourceLocation)
        #expect(current.cachedInput == legacy.cachedInput, "cachedInput 不一致: current=\(String(describing: current.cachedInput)) legacy=\(String(describing: legacy.cachedInput)) usage=\(usage)", sourceLocation: sourceLocation)
        #expect(current.cacheWrite == legacy.cacheWrite, "cacheWrite 不一致", sourceLocation: sourceLocation)
        #expect(current.cacheTotal == legacy.cacheTotal, "cacheTotal 不一致", sourceLocation: sourceLocation)
    }

    // MARK: - OpenAI 形态

    @Test("OpenAI 标准 usage 与修复前一致")
    func openAIStandardUsageMatchesLegacy() throws {
        try assertEquivalent([
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "total_tokens": 150
        ], anthropic: false)
    }

    @Test("OpenAI 缓存命中计数与修复前一致")
    func openAICacheUsageMatchesLegacy() throws {
        try assertEquivalent([
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "prompt_tokens_details": ["cached_tokens": 40]
        ], anthropic: false)
    }

    @Test("OpenAI 缓存写入计数与修复前一致")
    func openAICacheWriteMatchesLegacy() throws {
        try assertEquivalent([
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "cache_write_tokens": 30
        ], anthropic: false)
    }

    @Test("OpenAI 各别名组合与修复前一致")
    func openAIAliasesMatchLegacy() throws {
        // 逐个别名形态都过一遍，确保归一链的顺序没变。
        let variants: [[String: Any]] = [
            ["input_tokens": 10, "output_tokens": 5],
            ["prompt_token_count": 20, "output_token_count": 8],
            ["prompt_tokens": 30, "candidates_token_count": 12],
            ["input_token_count": 40, "completion_tokens": 16],
            ["prompt_tokens": 50, "cached_tokens": 20],
            ["prompt_tokens": 60, "cache_read_input_tokens": 25],
            ["prompt_tokens": 70, "prompt_cache_hit_tokens": 35],
            ["prompt_tokens": 80, "cache_creation_input_tokens": 45],
            ["prompt_tokens": 90, "input_tokens_details": ["cached_tokens": 15]],
            ["prompt_tokens": 91, "input_tokens_details": ["cache_write_tokens": 11]],
            ["prompt_tokens": 92, "prompt_tokens_details": ["cache_write_tokens": 12]],
            ["prompt_tokens": 93, "prompt_tokens_details": ["cached_tokens": 13, "cache_write_tokens": 14]],
            ["input_tokens": 94, "output_tokens": 47, "cached_input_tokens": 22],
        ]
        for usage in variants {
            try assertEquivalent(usage, anthropic: false)
        }
    }

    @Test("OpenAI 缺少 usage 时全部为 nil")
    func openAIMissingUsageYieldsNil() throws {
        let decoded = try decodedUsage([:], protocolName: "openai")
        let counts = ResponseTokenUsage.counts(from: decoded, anthropic: false)

        #expect(counts.input == nil)
        #expect(counts.output == nil)
        #expect(counts.cachedInput == nil)
        #expect(counts.cacheWrite == nil)
        #expect(counts.cacheTotal == nil)
    }

    // MARK: - Anthropic 形态

    @Test("Anthropic 标准 usage 与修复前一致")
    func anthropicStandardUsageMatchesLegacy() throws {
        try assertEquivalent([
            "input_tokens": 100,
            "output_tokens": 50,
            "cache_read_input_tokens": 30,
            "cache_creation_input_tokens": 20
        ], anthropic: true)
    }

    @Test("Anthropic 缓存命中计数与修复前一致")
    func anthropicCacheReadMatchesLegacy() throws {
        try assertEquivalent([
            "input_tokens": 100,
            "output_tokens": 50,
            "cached_tokens": 40
        ], anthropic: true)
    }

    @Test("Anthropic 各别名组合与修复前一致")
    func anthropicAliasesMatchLegacy() throws {
        let variants: [[String: Any]] = [
            ["prompt_tokens": 10, "completion_tokens": 5],
            ["input_tokens": 20, "output_token_count": 8],
            ["input_token_count": 30, "output_tokens": 12],
            ["input_tokens": 40, "cache_write_tokens": 16],
            ["input_tokens": 50, "prompt_tokens_details": ["cached_tokens": 20]],
            ["input_tokens": 60, "input_tokens_details": ["cached_tokens": 25]],
            ["input_tokens": 70, "prompt_tokens_details": ["cache_creation_input_tokens": 35]],
            ["input_tokens": 80, "input_tokens_details": ["cache_write_tokens": 45]],
            ["input_tokens": 81, "cached_input_tokens": 23],
            ["input_tokens": 90, "cached_input_tokens": 22],
            ["input_tokens": 91, "prompt_tokens_details": ["cache_creation_input_tokens": 15, "cache_write_tokens": 16]],
        ]
        for usage in variants {
            try assertEquivalent(usage, anthropic: true)
        }
    }

    @Test("Anthropic 缺少 usage 时全部为 nil")
    func anthropicMissingUsageYieldsNil() throws {
        let decoded = try decodedUsage([:], protocolName: "anthropic")
        let counts = ResponseTokenUsage.counts(from: decoded, anthropic: true)

        #expect(counts.input == nil)
        #expect(counts.output == nil)
        #expect(counts.cachedInput == nil)
        #expect(counts.cacheWrite == nil)
        #expect(counts.cacheTotal == nil)
    }

    // MARK: - 交叉协议

    @Test("同一份 usage 在两种协议下的读数各自与修复前一致")
    func sameUsageAcrossProtocolsMatchesLegacy() throws {
        let usage: [String: Any] = [
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "prompt_tokens_details": ["cached_tokens": 30]
        ]
        try assertEquivalent(usage, anthropic: false)
        try assertEquivalent(usage, anthropic: true)
    }
}
