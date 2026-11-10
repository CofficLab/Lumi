import LumiUI
import SwiftUI

/// V4（ZCode）「回到底部」按钮。
///
/// - Important: 只在**脱离跟随**且确实存在内容时出现。
///   点击后恢复跟随并贴底。
///
/// - Note: 几何按 ZCode 3.15.1：按钮 32×32、圆角 16、图标 16、
///   距右 16、距底 16。
struct ZCodeBackToBottomButton: View {
    /// 点击回调。
    let action: () -> Void

    @LumiTheme private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: ZCodeBackToBottomStyle.iconSize, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .frame(
                    width: ZCodeBackToBottomStyle.buttonSize,
                    height: ZCodeBackToBottomStyle.buttonSize
                )
                .background(
                    theme.surface.opacity(0.9),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .strokeBorder(theme.divider.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ZCodeAccessibilityIdentifiers.backToBottom)
        .accessibilityLabel(pluginLocalization.string("Back to bottom"))
        .help(pluginLocalization.string("Back to bottom"))
    }
}

/// 「回到底部」按钮的几何规格。
enum ZCodeBackToBottomStyle {
    /// 按钮边长。
    static let buttonSize: CGFloat = 32
    /// 图标尺寸。
    static let iconSize: CGFloat = 16
    /// 距右间距。
    static let trailingSpacing: CGFloat = 16
    /// 距底间距。
    static let bottomSpacing: CGFloat = 16
}
