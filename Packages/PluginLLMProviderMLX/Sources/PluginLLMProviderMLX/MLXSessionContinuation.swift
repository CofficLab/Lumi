import Foundation
import KitLLM

/// 跨轮复用 MLX `ChatSession` 的判定与记账。
///
/// 上层每回合都把完整历史交给 Provider。若上一轮建立的会话仍精确覆盖
/// 当前历史的前缀，就只追加新增消息，跳过对整段上下文的重复 prefill。
/// 任一前缀差异（编辑、重试、上下文压缩、切模型/工具）都必须重建会话，
/// 否则 KV 缓存会与提示词错位。
struct MLXSessionContinuation: Equatable {

    /// 会话身份：任一字段变化都不能复用。
    struct Identity: Equatable {
        let conversationID: UUID
        let providerID: String?
        let modelID: String
        let toolsSignature: String
    }

    enum Plan: Equatable {
        /// `messages[startIndex...]` 是尚未进入会话的新消息。
        case appendSuffix(startIndex: Int)
        /// 无法复用，按完整历史重建会话。
        case rebuild
    }

    let identity: Identity
    /// 已经进入会话 transcript 的历史消息。
    let consumedMessages: [LLMMessage]
    /// 上一轮生成的 assistant 回复：会话已自动记录它，下一轮必须跳过。
    let lastAssistant: LLMMessage?

    func plan(for messages: [LLMMessage], identity: Identity) -> Plan {
        guard identity == self.identity,
              messages.count >= consumedMessages.count,
              Array(messages.prefix(consumedMessages.count)) == consumedMessages
        else { return .rebuild }

        var startIndex = consumedMessages.count
        if let lastAssistant {
            guard messages.count > startIndex,
                  Self.matchesAssistant(messages[startIndex], produced: lastAssistant)
            else { return .rebuild }
            startIndex += 1
        }
        guard messages.count > startIndex else { return .rebuild }
        return .appendSuffix(startIndex: startIndex)
    }

    /// 落库的 assistant 必须与上一轮实际输出一致：用户编辑回复或重新生成后，
    /// 会话里的 transcript 不再是当前历史的等价前缀。
    static func matchesAssistant(_ stored: LLMMessage, produced: LLMMessage) -> Bool {
        guard stored.role == .assistant, stored.content == produced.content else { return false }
        return toolCallSignatures(stored.toolCalls) == toolCallSignatures(produced.toolCalls)
    }

    /// 工具调用的 id 在本地是重新生成的，只比较函数名与参数。
    static func toolCallSignatures(_ calls: [LLMToolCall]?) -> [String] {
        (calls ?? []).map { "\($0.name)\u{1F}\($0.arguments)" }
    }
}