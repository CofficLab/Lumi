import CoreGraphics
import LumiUI
import SwiftUI

/// V5（ChatGPT）「回到底部」按钮的呈现规格。
///
/// 基准是 V5 方案第 2.2 节：
/// - 32×32，底部偏移 16；
/// - **水平居中**，不遮挡右侧正文。
enum ChatGPTBackToBottomStyle {
    /// 按钮尺寸。
    static let size: CGFloat = 32
    /// 底部偏移。
    static let bottomSpacing: CGFloat = 16
    /// 图标尺寸。
    static let iconSize: CGFloat = 13
    /// 按钮与内容的水平间距（居中时不需要额外留白）。
    static let trailingSpacing: CGFloat = 0
}

/// V5（ChatGPT）「回到底部」按钮。
///
/// 只在用户脱离跟随且列表确有内容时出现。点击后恢复跟随并贴底。
struct ChatGPTBackToBottomButton: View {
    @LumiTheme private var theme

    /// 点击动作：恢复跟随并滚动到底部。
    let action: () -> Void

    /// 是否处于键盘 focus（用于键盘可达性）。
    @FocusState private var hasKeyboardFocus: Bool

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: ChatGPTBackToBottomStyle.iconSize, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .frame(
                    width: ChatGPTBackToBottomStyle.size,
                    height: ChatGPTBackToBottomStyle.size
                )
                .background(
                    theme.surface,
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .strokeBorder(theme.textSecondary.opacity(0.16), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($hasKeyboardFocus)
        .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.backToBottomButton)
        .accessibilityLabel(pluginLocalization.string("回到底部"))
        .help(pluginLocalization.string("回到底部"))
    }
}
