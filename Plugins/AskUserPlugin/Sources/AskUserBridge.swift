import Foundation
import LumiCoreKit

/// AskUser 插件桥接器
///
/// 保存内核通过 `PluginRuntimeContext.resumeToolCall` 注入的恢复回调，
/// 供渲染器在用户做出选择后调用。
///
/// 数据流：
/// ```
/// PluginRuntimeContext.resumeToolCall (内核注入)
///         ↓ (AskUserPlugin.configureRuntime 保存)
/// AskUserBridge.resume
///         ↓ (渲染器用户点击后调用)
/// 内核写回 ToolCall.result + 触发 AgentTurnService.run()
/// ```
@MainActor
public final class AskUserBridge: ObservableObject {
    public static let shared = AskUserBridge()

    private init() {}

    /// 恢复回调：(conversationId, toolCallId, answer)
    public var resumeHandler: (@MainActor (String, String, String) -> Void)?

    /// 用户做出选择后调用，触发恢复。
    public func resume(conversationId: String, toolCallId: String, answer: String) {
        resumeHandler?(conversationId, toolCallId, answer)
    }
}
