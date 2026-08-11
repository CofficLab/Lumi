import Foundation
import SwiftUI

// MARK: - Notification.Name

public extension Notification.Name {
    static let lumiConversationsDidChange = LumiKernelEvent.conversationsDidChange.notificationName
    static let lumiSelectedConversationDidChange = LumiKernelEvent.selectedConversationDidChange.notificationName
    static let lumiConversationTitleDidChange = LumiKernelEvent.conversationTitleDidChange.notificationName
    static let lumiConversationDidDelete = LumiKernelEvent.conversationDidDelete.notificationName
    static let lumiConversationWillDelete = LumiKernelEvent.conversationWillDelete.notificationName
}

// MARK: - UserInfo Keys

public enum LumiNotificationUserInfoKey {
    public static let conversationID = "conversationID"
}

public extension Notification {
    var lumiConversationID: UUID? {
        userInfo?[LumiNotificationUserInfoKey.conversationID] as? UUID
    }
}

// MARK: - NotificationCenter Subscribe Helpers

public extension NotificationCenter {
    /// Subscribe to `.lumiConversationsDidChange`.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiConversationsDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiConversationsDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }

    /// Subscribe to `.lumiConversationTitleDidChange`.
    /// Handler receives the conversation ID from userInfo.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiConversationTitleDidChange(_ handler: @escaping (UUID?) -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiConversationTitleDidChange, object: nil, queue: .main) { notification in
            handler(notification.lumiConversationID)
        }
    }

    /// Subscribe to `.lumiConversationDidDelete`.
    /// Handler receives the deleted conversation ID from userInfo.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiConversationDidDelete(_ handler: @escaping (UUID) -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiConversationDidDelete, object: nil, queue: .main) { notification in
            if let conversationID = notification.lumiConversationID {
                handler(conversationID)
            }
        }
    }

    /// Subscribe to `.lumiConversationWillDelete`.
    /// Handler receives the about-to-be-deleted conversation ID from userInfo
    /// (still accessible at this point — fetch title/etc. if needed).
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiConversationWillDelete(_ handler: @escaping (UUID) -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiConversationWillDelete, object: nil, queue: .main) { notification in
            if let conversationID = notification.lumiConversationID {
                handler(conversationID)
            }
        }
    }
}

// MARK: - SwiftUI View Extensions

@MainActor
public extension View {
    /// 监听 `.lumiConversationsDidChange` 通知
    func onLumiConversationsDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationsDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiSelectedConversationDidChange` 通知（当前选中会话切换）。
    ///
    /// 与 `onLumiConversationsDidChange`（列表增删/标题/活跃标记）区分：本事件只在
    /// `selectedConversationID` 变化时触发。关心「当前会话」的工具栏应优先用它，
    /// 避免被无关的列表变更打扰。
    func onLumiSelectedConversationDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiSelectedConversationDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiSelectedConversationDidChange` 通知，并传出当前选中的会话 ID。
    ///
    /// `conversationID` 为 nil 表示已取消选中（deselect）。需要按会话过滤或缓存
    /// 当前 ID 的消费者应使用此重载。
    func onLumiSelectedConversationDidChange(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiSelectedConversationDidChange)) { notification in
            action(notification.lumiConversationID)
        }
    }

    /// 监听 `.lumiConversationTitleDidChange` 通知
    func onLumiConversationTitleDidChange(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationTitleDidChange)) { notification in
            action(notification.lumiConversationID)
        }
    }

    /// 监听 `.lumiConversationDidDelete` 通知
    func onLumiConversationDidDelete(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationDidDelete)) { notification in
            if let conversationID = notification.lumiConversationID {
                action(conversationID)
            }
        }
    }

    /// 监听 `.lumiConversationWillDelete` 通知(对话即将被删除,但 ID 仍可访问)
    func onLumiConversationWillDelete(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationWillDelete)) { notification in
            if let conversationID = notification.lumiConversationID {
                action(conversationID)
            }
        }
    }
}
