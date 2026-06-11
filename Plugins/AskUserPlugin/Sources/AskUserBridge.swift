import Foundation
import LumiCoreKit

/// AskUser 插件桥接器
///
/// 保存 `AskUserPlugin.configureAskUserResume` 注入的恢复回调，
/// 供渲染器在用户做出选择后调用。
///
/// 数据流：
/// ```
/// LumiAskUserResuming.resumeAfterAskUser (ChatService)
///         ↓ (AskUserPlugin.configureAskUserResume 保存)
/// AskUserBridge.resume
///         ↓ (渲染器用户点击后调用)
/// ChatService 写回 tool result 并继续 runAgentTurn
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
