import Combine
import Foundation
import os
import SuperLogKit

/// Kernel event dispatcher.
///
/// 所有需要广播的事件，都通过这个对象发出。
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

    /// 发送 `.lumiSelectedConversationDidChange` 通知。
    ///
    /// 在 `selectedConversationID` 发生变化时调用（select/deselect/create 自动选中/
    /// 启动恢复/delete 回退）。`conversationID` 为 nil 表示取消选中。
    /// 与 `.lumiConversationsDidChange`（列表增删/标题/活跃标记）区分：本事件只关心
    /// 「当前选中会话」的切换，供关心 selectedConversationID 的视图精确订阅，
    /// 避免被无关的列表变更打扰。
    public func postSelectedConversationDidChange(object: Any? = nil, conversationID: UUID?) {
        let userInfo = conversationID.map {
            [LumiNotificationUserInfoKey.conversationID: $0] as [AnyHashable: Any]
        }
        post(.selectedConversationDidChange, object: object, userInfo: userInfo)
    }

    public func postConversationTitleDidChange(object: Any? = nil, conversationID: UUID?) {
        let userInfo = conversationID.map {
            [LumiNotificationUserInfoKey.conversationID: $0] as [AnyHashable: Any]
        }
        post(.conversationTitleDidChange, object: object, userInfo: userInfo)
    }

    public func postConversationDidDelete(object: Any? = nil, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiNotificationUserInfoKey.conversationID: conversationID,
        ]
        post(.conversationDidDelete, object: object, userInfo: userInfo)
    }

    public func postConversationWillDelete(object: Any? = nil, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiNotificationUserInfoKey.conversationID: conversationID,
        ]
        post(.conversationWillDelete, object: object, userInfo: userInfo)
    }

    // MARK: - AgentTurnRunner Notifications

    public func postMessageSaved(
        object: Any? = nil,
        messageID: UUID,
        conversationID: UUID,
        role: String
    ) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.messageIDKey: messageID,
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiMessageSavedNotification.roleKey: role,
        ]
        post(.messageSaved, object: object, userInfo: userInfo)
    }

    public func postTurnStarted(
        object: Any? = nil,
        conversationID: UUID,
        turnID: UUID,
        parentConversationID: UUID? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnStartedNotification.turnIDKey: turnID,
        ]
        if let parentConversationID {
            userInfo[LumiTurnStartedNotification.parentConversationIDKey] = parentConversationID
        }
        post(.turnStarted, object: object, userInfo: userInfo)
    }

    public func postTurnCompleted(object: Any? = nil, conversationID: UUID, turnID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnStartedNotification.turnIDKey: turnID,
            LumiTurnFinishedNotification.reasonKey: LumiTurnEndReason.completed.rawValue,
        ]
        post(.turnCompleted, object: object, userInfo: userInfo)
    }

    public func postTurnFinished(
        object: Any? = nil,
        conversationID: UUID,
        turnID: UUID?,
        reason: LumiTurnEndReason,
        parentConversationID: UUID? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: reason.rawValue,
        ]
        if let turnID {
            userInfo[LumiTurnFinishedNotification.turnIDKey] = turnID
        }
        if let parentConversationID {
            userInfo[LumiTurnFinishedNotification.parentConversationIDKey] = parentConversationID
        }
        post(.turnFinished, object: object, userInfo: userInfo)
    }
}
