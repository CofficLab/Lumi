import Foundation
import LumiKernel

/// 纯函数:计算 V1 (brief) 模式下应**默认展开**的工具步骤组(助手消息 id)集合。
///
/// 从视图模型抽出为独立类型,便于单元测试(无需构造 kernel / AgentTurnManaging)。
///
/// 规则:所有步骤组都默认收起。用户可以通过点击摘要行手动展开。
///
/// 详见 `MessageListViewModel.recomputeActiveStepGroups`。
enum ActiveStepGroupResolver {

    /// - Parameters:
    ///   - displayRows: 当前展示行(已含流式临时行,按时间升序)。
    ///   - isTurnActive: 当前会话的 turn 是否进行中。
    ///   - verbosity: 当前会话详细程度(非 brief 时直接返回空集合)。
    /// - Returns: 应默认展开的助手消息 id 集合。
    static func resolve(
        displayRows: [LumiChatMessage],
        isTurnActive: Bool,
        verbosity: LumiResponseVerbosity
    ) -> Set<UUID> {
        []
    }

    /// 判断一条消息是否构成"turn 边界"(其后的工具调用组属于新一轮 turn)。
    /// - 助手且无工具调用且正文非空:即上一轮的最终自然语言回复。
    /// - 或显式的 turn-completed 标记(renderKind / 内容)。
    static func isTurnBoundary(_ message: LumiChatMessage) -> Bool {
        if message.renderKind == "turn-completed"
            || message.content == LumiChatMarkers.turnCompleted {
            return true
        }
        return message.role == .assistant
            && (message.toolCalls ?? []).isEmpty
            && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
