import SwiftUI

// MARK: - Notification Extension (Input / Chat Events)

extension Notification.Name {
    /// 用户在输入区域发送了新消息（用于驱动消息列表滚动等 UI 行为）
    static let agentInputDidSendMessage = Notification.Name("agentInputDidSendMessage")

    /// 用户点击「添加到聊天」，将文件中的选区信息插入到聊天输入框
    /// userInfo: ["text": String] — 要插入的格式化文本
    static let addToChat = Notification.Name("addToChat")
}

// MARK: - NotificationCenter Helpers

extension NotificationCenter {
    /// 发送「用户发送新消息」事件
    static func postUserDidSendMessage() {
        NotificationCenter.default.post(name: .agentInputDidSendMessage, object: nil)
    }

    /// 发送「添加到聊天」事件
    /// - Parameter text: 要插入聊天输入框的格式化文本
    static func postAddToChat(text: String) {
        NotificationCenter.default.post(
            name: .addToChat,
            object: nil,
            userInfo: ["text": text]
        )
    }
}

// MARK: - View Extensions for Input Events

extension View {
    /// 监听「用户发送新消息」事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onAgentInputDidSendMessage(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .agentInputDidSendMessage)) { _ in
            action()
        }
    }

    /// 监听「添加到聊天」事件
    /// - Parameter action: 事件处理闭包，参数为要插入的文本
    /// - Returns: 修改后的视图
    func onAddToChat(perform action: @escaping (String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .addToChat)) { notification in
            if let text = notification.userInfo?["text"] as? String {
                action(text)
            }
        }
    }
}
