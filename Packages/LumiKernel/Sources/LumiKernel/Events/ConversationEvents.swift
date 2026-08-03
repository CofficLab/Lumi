import Foundation
import SwiftUI

// MARK: - Notification.Name

public extension Notification.Name {
    static let lumiConversationsDidChange = LumiKernelEvent.conversationsDidChange.notificationName
    static let lumiConversationTitleDidChange = LumiKernelEvent.conversationTitleDidChange.notificationName
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

// MARK: - NotificationCenter Posting Helpers

public extension NotificationCenter {
    /// 发送 `.lumiConversationsDidChange` 通知
    static func postLumiConversationsDidChange() {
        NotificationCenter.default.post(name: .lumiConversationsDidChange, object: nil)
    }

    /// 发送 `.lumiConversationTitleDidChange` 通知
    static func postLumiConversationTitleDidChange(conversationID: UUID?) {
        let userInfo = conversationID.map {
            [LumiNotificationUserInfoKey.conversationID: $0] as [AnyHashable: Any]
        }
        NotificationCenter.default.post(name: .lumiConversationTitleDidChange, object: nil, userInfo: userInfo)
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

    /// 监听 `.lumiConversationTitleDidChange` 通知
    func onLumiConversationTitleDidChange(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationTitleDidChange)) { notification in
            action(notification.lumiConversationID)
        }
    }
}
