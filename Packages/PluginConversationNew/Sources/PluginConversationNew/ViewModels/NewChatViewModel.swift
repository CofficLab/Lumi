import Combine
import Foundation

/// 新会话按钮唯一的数据入口。
///
/// View 只触发用户意图，不直接访问 Kernel 或 Provider；取消选择当前会话等
/// 业务逻辑通过 `NewChatCapability` 收敛。
@MainActor
final class NewChatViewModel: ObservableObject {
    private let capability: any NewChatCapability

    init(capability: any NewChatCapability) {
        self.capability = capability
    }

    /// 用户点击「新建会话」：取消当前会话选择。
    func startNewChat() {
        capability.deselectConversation()
    }
}
