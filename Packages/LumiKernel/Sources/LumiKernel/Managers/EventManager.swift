import Combine
import Foundation
import os
import SuperLogKit

/// Kernel event dispatcher.
///
/// 所有需要对外广播的内核事件，都通过这个对象发出。
@MainActor
public final class EventManager: ObservableObject, SuperLog {
    nonisolated public static let emoji = "📣"
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "kernel.event-manager")

    public init() {}

    public func post(
        _ event: LumiKernelEvent,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)post event=\(event.rawValue) object=\(String(describing: object.map { type(of: $0) })) userInfoKeys=\(userInfo?.keys.map { String(describing: $0) }.sorted().joined(separator: ",") ?? "nil")")
        }
        NotificationCenter.default.post(name: event.notificationName, object: object, userInfo: userInfo)
    }

    public func postEnabledPluginsDidChange(object: Any? = nil) {
        post(.enabledPluginsDidChange, object: object)
    }

    public func postMessagesDidChange(object: Any? = nil, conversationID: UUID? = nil) {
        let userInfo = conversationID.map {
            [LumiNotificationUserInfoKey.conversationID: $0] as [AnyHashable: Any]
        }
        post(.messagesDidChange, object: object, userInfo: userInfo)
    }

    public func postConversationsDidChange(object: Any? = nil) {
        post(.conversationsDidChange, object: object)
    }

    public func postConversationTitleDidChange(object: Any? = nil, conversationID: UUID?) {
        let userInfo = conversationID.map {
            [LumiNotificationUserInfoKey.conversationID: $0] as [AnyHashable: Any]
        }
        post(.conversationTitleDidChange, object: object, userInfo: userInfo)
    }
}
