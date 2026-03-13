import SwiftUI

// MARK: - Notification Extension (Input / Chat Events)

extension Notification.Name {
    /// 用户在输入区域发送了新消息（用于驱动消息列表滚动等 UI 行为）
    static let agentInputDidSendMessage = Notification.Name("agentInputDidSendMessage")
}

// MARK: - NotificationCenter Helpers

extension NotificationCenter {
    /// 发送「用户发送新消息」事件
    /// 建议由核心 AgentVM 在确认发送请求后调用，而不是由具体 UI 组件调用。
    static func postAgentUserDidSendMessage() {
        NotificationCenter.default.post(name: .agentInputDidSendMessage, object: nil)
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
}

