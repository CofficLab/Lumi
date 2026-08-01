import Foundation
import LumiKernel

/// 纯函数:计算 V1 (brief) 模式下应**默认展开**的工具步骤组(助手消息 id)集合。
///
/// 从视图模型抽出为独立类型,便于单元测试(无需构造 kernel / AgentTurnManaging)。
///
/// 规则:
/// 1. turn 未进行中(`isTurnActive == false`)或非 brief 模式 → 空集合(全部收起)。
/// 2. turn 进行中:取**最后一条 turn 边界消息**(上一轮最终回复 / turn-completed 标记)
///    之后、带工具调用的助手消息 id。
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
        guard verbosity == .brief, isTurnActive else { return [] }

        // 找最后一条 turn 边界(上一轮最终回复 / turn-completed 标记)的下标。
        let lastBoundaryIndex = displayRows.lastIndex(where: { isTurnBoundary($0) }) ?? -1
        return Set(
            displayRows
                .dropFirst(lastBoundaryIndex + 1)
                .compactMap { message -> UUID? in
                    guard message.role == .assistant,
                          !(message.toolCalls ?? []).isEmpty
                    else { return nil }
                    return message.id
                }
        )
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
