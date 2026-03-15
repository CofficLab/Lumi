import SwiftUI
import MagicKit

// MARK: - Message Bubble Style Extensions

extension View {
    /// 应用消息气泡样式
    /// - Parameters:
    ///   - role: 消息角色
    ///   - isError: 是否是错误消息
    /// - Returns: 应用了气泡样式的视图
    public func messageBubbleStyle(role: MessageRole, isError: Bool) -> some View {
        self
            .font(DesignTokens.Typography.code)
            .padding(10)
            .padding(.trailing, role == .assistant ? 20 : 0)
            .background(bubbleBackgroundColor(role: role, isError: isError))
            .foregroundColor(textColor(isError: isError))
            .cornerRadius(12)
    }

    /// 气泡背景颜色
    /// - Parameters:
    ///   - role: 消息角色
    ///   - isError: 是否是错误消息
    /// - Returns: 背景颜色
    public func bubbleBackgroundColor(role: MessageRole, isError: Bool) -> Color {
        if isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        switch role {
        case .user:
            return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }

    /// 文本颜色
    /// - Parameter isError: 是否是错误消息
    /// - Returns: 文本颜色
    public func textColor(isError: Bool) -> Color {
        if isError {
            return DesignTokens.Color.semantic.error
        }
        return DesignTokens.Color.semantic.textPrimary
    }
}
