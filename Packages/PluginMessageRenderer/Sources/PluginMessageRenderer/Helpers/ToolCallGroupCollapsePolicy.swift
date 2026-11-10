import Foundation
import KitAgentTool
import ProviderConversation
import ProviderMessage

/// 工具调用组的「折叠 / 展开」决策（纯逻辑，便于单元测试）。
///
/// **只有 V2（standard）折叠。** V1（brief）与 V3（detailed）都保持
/// 逐条铺开的原样：
///
/// - **V1**：回复级别 brief 被升格为 standard 以复用 V2 的内容布局
///   （见 `AssistantMessageView.contentVerbosity`），因此「是否折叠」
///   **不能**用升格后的级别判断——必须拿**原始级别**。
/// - **V3**：detailed 的定位就是「展示更多细节」，折叠会与该定位相悖。
///
/// 本类型回答三个问题：
///
/// 1. **该不该折叠？** —— 只有 V2 且多于一个调用才折叠。单个调用直接铺开，
///    免得为一个调用凭空加一层「点开才看得见」的间接。
/// 2. **该不该强制展开？** —— 组内只要有一个调用在**等用户**，
///    就绝不能折叠：授权卡片、ask_user 交互卡、系统权限卡都是
///    「必须被看见才能推进」的入口，藏进 popover 等于让回合永远等下去。
enum ToolCallGroupCollapsePolicy {
    /// 组内是否存在「正在等用户处理」的调用。
    ///
    /// 判定与授权卡片渲染器（`ToolApprovalRowRenderer.canRender`）保持
    /// 同一套语义，避免出现「卡片已经被判定为要画，却因为被折叠而看不见」
    /// 这种自相矛盾的状态：
    ///
    /// - `authorizationState == .pendingAuthorization`：等待用户授权；
    /// - `result?.awaitingUserResponse == true`：工具挂起，等用户作答。
    ///
    /// - Note: `authorizationState` 缺失（nil）按 `pendingAuthorization` 处理
    ///   （与 `LumiToolCallAgentBridge.agentToolCall` 的回退一致），
    ///   但只有「结果也还没出来」时才据此判定为挂起——否则旧数据里
    ///   已完成却没写授权终态的调用会被误判为挂起，导致永远不折叠。
    static func hasAwaitingUserInteraction(_ toolCalls: [MessageToolCall]) -> Bool {
        toolCalls.contains { toolCall in
            if toolCall.result?.awaitingUserResponse == true {
                return true
            }
            guard toolCall.result == nil else { return false }
            let state = toolCall.authorizationState
                .flatMap(ToolCallAuthorizationState.init(rawValue:))
                ?? .pendingAuthorization
            return state == .pendingAuthorization
        }
    }

    /// 该组是否应当以「一行摘要 + popover」的形式折叠。
    ///
    /// - Parameter verbosity: **原始**回复级别（未经
    ///   `AssistantMessageView.contentVerbosity` 升格）。传升格后的值会
    ///   让 V1 被当成 V2 连坐折叠。
    /// - Returns: `true` 表示折叠；`false` 表示逐条铺开。
    static func shouldCollapse(
        _ toolCalls: [MessageToolCall],
        verbosity: ResponseVerbosity
    ) -> Bool {
        // 只有 V2 折叠：V1 与 V3 保持原有逐条铺开的效果。
        guard verbosity == .standard else { return false }
        // 少于两个调用：铺开即可，折叠没有收益。
        guard toolCalls.count > 1 else { return false }
        // 有交互挂起：必须让用户看得见，不能藏。
        if hasAwaitingUserInteraction(toolCalls) { return false }
        return true
    }
}
