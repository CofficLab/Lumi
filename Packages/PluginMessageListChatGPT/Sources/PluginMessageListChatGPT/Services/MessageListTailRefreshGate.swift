import Foundation

/// 串行化消息尾部刷新，并把事件突发收敛成「至多一次活动刷新 + 一次尾部刷新」。
///
/// - Important: `run` 是主线程隔离的，因为它的调用方会发布 SwiftUI 状态。
///   活动操作挂在 I/O 上时，重叠的调用方只标记「需要再跑一轮」并直接返回，
///   不派生更多工作。
@MainActor
final class MessageListTailRefreshGate {
    private var isRunning = false
    private var needsTrailingRefresh = false

    /// 运行 `operation`，直到它的最后一次挂起期间没有新请求到达。
    ///
    /// 只有拥有活动轮次的调用方会拿到 `true`；重叠的调用方返回 `false`，
    /// 避免重复触发刷新后的滚动动作。
    func run(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
        guard !isRunning else {
            needsTrailingRefresh = true
            return false
        }

        isRunning = true
        defer {
            isRunning = false
            needsTrailingRefresh = false
        }

        var didChange = false
        repeat {
            needsTrailingRefresh = false
            didChange = await operation() || didChange
        } while needsTrailingRefresh

        return didChange
    }
}

enum MessageListNotificationFilter {
    /// 没有会话 ID 的事件视为旧的全局事件。
    static func shouldHandle(
        eventConversationID: UUID?,
        selectedConversationID: UUID?
    ) -> Bool {
        guard let selectedConversationID else { return false }
        guard let eventConversationID else { return true }
        return eventConversationID == selectedConversationID
    }
}
