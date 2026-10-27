import Foundation
@preconcurrency import MLXLMCommon
import Tokenizers

/// 把 `Tokenizers.Tokenizer` 适配为 `MLXLMCommon.Tokenizer`。
///
/// mlx-swift-lm 3.x 不再内置 HuggingFace tokenizer 实现，要求调用方提供
/// `TokenizerLoader`。这里桥接 swift-transformers 的 `Tokenizer` 协议，
/// 避免依赖 `MLXHuggingFace` 的宏目标（宏需要在 Xcode 中逐次手动信任）。
///
/// swift-transformers 的 `Message` / `ToolSpec` 均为 `[String: any Sendable]`，
/// 与 `MLXLMCommon.Tokenizer` 的入参形状一致，因此可直接透传。
struct MLXTokenizerAdapter: MLXLMCommon.Tokenizer {
    let inner: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        inner.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        inner.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        inner.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        inner.convertIdToToken(id)
    }

    var bosToken: String? { inner.bosToken }
    var eosToken: String? { inner.eosToken }
    var unknownToken: String? { inner.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try inner.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

/// 从本地模型目录加载 swift-transformers 的 `AutoTokenizer`。
struct MLXTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await AutoTokenizer.from(pretrained: directory.absoluteString)
        return MLXTokenizerAdapter(inner: tokenizer)
    }
}
