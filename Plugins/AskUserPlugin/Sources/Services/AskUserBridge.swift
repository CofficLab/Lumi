import Foundation
import LumiKernel

/// AskUser 插件桥接器
///
/// 用户做出选择后，通过 NotificationCenter 发送通知，
/// ChatService 监听通知并恢复 Agent 循环。
///
/// 数据流：
/// ```
/// 渲染器用户点击 → AskUserBridge.resume(...)
///         ↓
/// 发送 lumiAskUserDidAnswer 通知
///         ↓
/// ChatService 监听通知 → resumeAfterAskUser() → continueAgentTurn()
/// ```
@MainActor
public final class AskUserBridge: ObservableObject {
    public static let shared = AskUserBridge()

    private init() {}

    /// 用户做出选择后调用，发送通知触发恢复。
    public func resume(conversationId: String, toolCallId: String, answer: String) {
        NotificationCenter.default.post(
            name: .lumiAskUserDidAnswer,
            object: nil,
            userInfo: [
                LumiAskUserNotification.conversationIDKey: conversationId,
                LumiAskUserNotification.toolCallIDKey: toolCallId,
                LumiAskUserNotification.answerKey: answer
            ]
        )
    }
}
