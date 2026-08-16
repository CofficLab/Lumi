import Foundation
import ProviderConversation
import ProviderMessage

/// 纯函数：计算 V1 (brief) 模式下应**默认展开**的工具步骤组（助手消息 id）集合。
///
/// 从视图模型抽出为独立类型，便于单元测试。
/// 规则：所有步骤组都默认收起。用户可以通过点击摘要行手动展开。
enum ActiveStepGroupResolver {

    /// - Returns: 应默认展开的助手消息 id 集合（当前策略恒为空，全部默认收起）。
    static func resolve(
        displayRows: [Message],
        isTurnActive: Bool,
        verbosity: LumiResponseVerbosity
    ) -> Set<UUID> {
        []
    }

    /// 判断一条消息是否构成"turn 边界"（其后的工具调用组属于新一轮 turn）。
    /// - 助手且无工具调用且正文非空：即上一轮的最终自然语言回复。
    /// - 或显式的 turn-completed 标记（renderKind / 内容）。
    static func isTurnBoundary(_ message: Message) -> Bool {
        if message.renderKind == "turn-completed"
            || message.content == LumiChatMarkers.turnCompleted {
            return true
        }
        return message.role == .assistant
            && (message.toolCalls ?? []).isEmpty
            && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
