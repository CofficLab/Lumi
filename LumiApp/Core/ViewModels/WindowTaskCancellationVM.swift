import Foundation

///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。nRootView 监听其 `conversationIdToCancel` 变化取消发送任务。
///「待取消」的会话 ID
/// WindowTaskCancellationVM
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// RootView 监听其 `conversationIdToCancel` 变化取消发送任务。
@MainActor
final class WindowTaskCancellationVM: ObservableObject {
    @Published private(set) var conversationIdToCancel: UUID?

    func requestCancel(conversationId: UUID) {
        conversationIdToCancel = conversationId
    }

    func consumeRequest() {
        conversationIdToCancel = nil
    }
}
