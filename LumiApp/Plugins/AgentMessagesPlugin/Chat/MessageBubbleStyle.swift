import SwiftUI
import MagicKit

// MARK: - Message Bubble Style Extensions

extension View {
    /// 应用消息气泡样式
    /// - Parameters:
    ///   - role: 消息角色
    ///   - isError: 是否是错误消息
    /// - Returns: 应用了气泡样式的视图
    func messageBubbleStyle(
        role: MessageRole,
        isError: Bool,
        style: AppMessageBubbleStyle = .default
    ) -> some View {
        self
            .appMessageBubble(role: role, isError: isError, style: style)
    }
}
