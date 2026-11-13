import Foundation

/// 从**已解码**的响应里读 token 用量。
///
/// ## 为什么要有它
///
/// 非流式响应此前会被完整解析三次：一次投机性的错误信封探测、一次正式
/// 的响应解码、以及一次只为读 `usage` 的 `JSONSerialization` 重解析。
/// 实测在 210 KB 的响应上，三次合计 2.53 ms，其中 `usage` 那次重解析占
/// 近六成（Issue #1270）。
///
/// 现在 `usage` 随响应一起解码，本类型只负责把已解码的字段按**既有**
/// 别名规则归一成计数——不触碰原始字节，因此没有额外解析开销。
///
/// ## 别名规则
///
/// 各家供应商的 usage 字段名不统一：`prompt_tokens` / `input_tokens` /
/// `prompt_token_count` / `input_token_count` 都有，输出侧同理；缓存计数
/// 既可能平铺在 usage 顶层，也可能嵌在 `*_tokens_details` 里。规则与
/// 修复前逐字对齐，数值不会因此改变。
public enum ResponseTokenUsage {

    /// token 计数。
    public struct Counts: Sendable {
        public let input: Int?
        public let output: Int?
        public let cachedInput: Int?
        public let cacheWrite: Int?
        public let cacheTotal: Int?
    }

    /// 已解码的 usage 字段视图。
    ///
    /// OpenAI 兼容协议与 Anthropic 兼容协议的 usage 结构不同，但归一化时
    /// 需要的字段名是同一套别名。这个协议把两者统一成同一组可空字段，
    /// 让归一逻辑只写一份。
    public protocol UsageFields {
        var inputTokens: Int? { get }
        var outputTokens: Int? { get }
        var promptTokens: Int? { get }
        var completionTokens: Int? { get }
        var promptTokenCount: Int? { get }
        var inputTokenCount: Int? { get }
        var candidatesTokenCount: Int? { get }
        var outputTokenCount: Int? { get }
        var cachedInputTokens: Int? { get }
        var cacheWriteTokens: Int? { get }
        var cacheCreationInputTokens: Int? { get }
        var cacheReadInputTokens: Int? { get }
        var promptCacheHitTokens: Int? { get }
        var cachedTokens: Int? { get }
        var promptTokensDetailsCachedTokens: Int? { get }
        var promptTokensDetailsCacheWriteTokens: Int? { get }
        var promptTokensDetailsCacheCreationInputTokens: Int? { get }
        var inputTokensDetailsCachedTokens: Int? { get }
        var inputTokensDetailsCacheWriteTokens: Int? { get }
        var inputTokensDetailsCacheCreationInputTokens: Int? { get }
    }

    /// 从已解码的 usage 读计数。
    ///
    /// - Parameters:
    ///   - usage: 已解码的 usage（`nil` 表示响应里没有这个字段）。
    ///   - anthropic: 是否按 Anthropic 兼容协议解读字段名。
    public static func counts(
        from usage: (any UsageFields)?,
        anthropic: Bool
    ) -> Counts {
        guard let usage else {
            return Counts(input: nil, output: nil, cachedInput: nil, cacheWrite: nil, cacheTotal: nil)
        }

        let input: Int?
        let output: Int?
        if anthropic {
            input = usage.inputTokens
                ?? usage.promptTokens
                ?? usage.inputTokenCount
            output = usage.outputTokens
                ?? usage.completionTokens
                ?? usage.outputTokenCount
        } else {
            input = usage.promptTokens
                ?? usage.inputTokens
                ?? usage.promptTokenCount
                ?? usage.inputTokenCount
            output = usage.completionTokens
                ?? usage.outputTokens
                ?? usage.candidatesTokenCount
                ?? usage.outputTokenCount
        }

        let cachedInput = anthropic
            ? anthropicCacheReadTokens(from: usage)
            : openAICacheReadTokens(from: usage)
        let cacheWrite = anthropic
            ? anthropicCacheWriteTokens(from: usage)
            : openAICacheWriteTokens(from: usage)
        let cacheTotal = anthropic
            ? AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
                inputTokens: input,
                cachedInputTokens: cachedInput,
                cacheWriteInputTokens: cacheWrite
            )
            : input
        return Counts(
            input: input,
            output: output,
            cachedInput: cachedInput,
            cacheWrite: cacheWrite,
            cacheTotal: cacheTotal
        )
    }

    /// OpenAI 形态的缓存读计数。
    ///
    /// 口径与 `OpenAICompatibleProviderAdapter.cacheReadInputTokens(from:)`
    /// 一致：顶层 `cached_tokens` → `prompt_tokens_details.cached_tokens`
    /// → `input_tokens_details.cached_tokens` → `cache_read_input_tokens`
    /// → `prompt_cache_hit_tokens`。
    private static func openAICacheReadTokens(
        from usage: any UsageFields
    ) -> Int? {
        usage.cachedTokens
            ?? usage.promptTokensDetailsCachedTokens
            ?? usage.inputTokensDetailsCachedTokens
            ?? usage.cacheReadInputTokens
            ?? usage.promptCacheHitTokens
    }

    /// OpenAI 形态的缓存写计数。
    ///
    /// 口径与 `OpenAICompatibleProviderAdapter.cacheWriteInputTokens(from:)`
    /// 一致。
    private static func openAICacheWriteTokens(
        from usage: any UsageFields
    ) -> Int? {
        usage.cacheWriteTokens
            ?? usage.cacheCreationInputTokens
            ?? usage.promptTokensDetailsCacheWriteTokens
            ?? usage.inputTokensDetailsCacheWriteTokens
    }

    /// Anthropic 形态的缓存读计数。
    ///
    /// 口径与修复前 `VendorLLMProvider.tokenCounts(from:anthropic:)` 一致：
    /// `cache_read_input_tokens` → `cached_tokens`
    /// → `prompt_tokens_details.cached_tokens`
    /// → `input_tokens_details.cached_tokens`。
    ///
    /// - Important: 这里**刻意不认** `cached_input_tokens`。那是
    ///   `AnthropicCompatibleProviderAdapter.cacheReadInputTokens` 的口径，
    ///   与本函数原本的取值链不同——两套口径在真实响应上会给出不同数值。
    ///   归一化必须逐字复刻修复前的行为，否则 token 统计与缓存命中率会
    ///   悄悄变化（Issue #1270）。
    private static func anthropicCacheReadTokens(
        from usage: any UsageFields
    ) -> Int? {
        usage.cacheReadInputTokens
            ?? usage.cachedTokens
            ?? usage.promptTokensDetailsCachedTokens
            ?? usage.inputTokensDetailsCachedTokens
    }

    /// Anthropic 形态的缓存写计数。
    ///
    /// 口径与 `AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(from:)`
    /// 一致：顶层 `cache_creation_input_tokens` → `cache_write_tokens`
    /// → `prompt_tokens_details.cache_creation_input_tokens`
    /// → `input_tokens_details.cache_write_tokens`。
    private static func anthropicCacheWriteTokens(
        from usage: any UsageFields
    ) -> Int? {
        usage.cacheCreationInputTokens
            ?? usage.cacheWriteTokens
            ?? usage.promptTokensDetailsCacheCreationInputTokens
            ?? usage.inputTokensDetailsCacheWriteTokens
    }
}

// MARK: - 协议一致性

extension OpenAICompatibleResponse.Usage: ResponseTokenUsage.UsageFields {}

extension AnthropicCompatibleResponse.Usage: ResponseTokenUsage.UsageFields {}
