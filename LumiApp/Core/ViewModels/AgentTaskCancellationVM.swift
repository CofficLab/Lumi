import Foundation

/// 由 UI 写入「待取消」的会话 ID，`RootView` 监听后交给 `CancelAgentTaskHandler` 执行，再清空。
@MainActor
final class AgentTaskCancellationVM: ObservableObject {
    @Published private(set) var conversationIdToCancel: UUID?

    func requestCancel(conversationId: UUID) {
        conversationIdToCancel = conversationId
    }

    func consumeRequest() {
        conversationIdToCancel = nil
    }
}
