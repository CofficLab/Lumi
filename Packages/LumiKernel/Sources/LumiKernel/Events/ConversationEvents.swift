import Foundation
import SwiftUI

// MARK: - Notification.Name

public extension Notification.Name {
    static let lumiConversationsDidChange = LumiKernelEvent.conversationsDidChange.notificationName
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
}
