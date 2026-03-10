import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 用户消息已发出的通知
    /// object: String (消息内容)
    static let userMessageSent = Notification.Name("userMessageSent")

    /// 用户消息已保存到数据库的通知
    /// object: ChatMessage (消息对象)
    static let userMessageSaved = Notification.Name("userMessageSaved")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送用户消息已发出的通知
    /// - Parameter message: 消息内容
    static func postUserMessageSent(message: String) {
        NotificationCenter.default.post(
            name: .userMessageSent,
            object: message
        )
    }

    /// 发送用户消息已保存到数据库的通知
    /// - Parameter message: 消息对象
    static func postUserMessageSaved(message: ChatMessage) {
        NotificationCenter.default.post(
            name: .userMessageSaved,
            object: message
        )
    }
}

// MARK: - View Extensions for Input Events

extension View {
    /// 监听用户消息已发出的事件
    /// - Parameter action: 事件处理闭包，参数为消息内容
    /// - Returns: 修改后的视图
    func onUserMessageSent(perform action: @escaping (String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .userMessageSent)) { notification in
            if let message = notification.object as? String {
                action(message)
            }
        }
    }

    /// 监听用户消息已保存到数据库的事件
    /// - Parameter action: 事件处理闭包，参数为消息对象
    /// - Returns: 修改后的视图
    func onUserMessageSaved(perform action: @escaping (ChatMessage) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .userMessageSaved)) { notification in
            if let message = notification.object as? ChatMessage {
                action(message)
            }
        }
    }
}
