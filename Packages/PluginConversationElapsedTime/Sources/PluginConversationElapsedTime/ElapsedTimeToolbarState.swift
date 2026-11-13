import Foundation

/// header 栏模型用时状态。
///
/// 保持 internal 以便单元测试直接断言「Provider 事件 → header 状态」的
/// 转发链路，对外仍不暴露任何 API。
@MainActor
final class ElapsedTimeToolbarState {
    enum Event {
        case selectedConversationChanged(UUID?)
        case messagesChanged(conversationID: UUID)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var selectedConversationID: UUID?
    private var observers: [UUID: (Event) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setSelectedConversationID(_ id: UUID?) {
        guard selectedConversationID != id else { return }
        selectedConversationID = id
        notify(.selectedConversationChanged(id))
    }

    func markMessagesChanged(conversationID: UUID) {
        notify(.messagesChanged(conversationID: conversationID))
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
