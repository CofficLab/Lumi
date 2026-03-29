import SwiftUI
import MagicKit

// MARK: - Raw Message Toggle Button

/// 原始消息切换按钮
/// 用于在原始 Markdown 源码和渲染视图之间切换
struct RawMessageToggleButton: View {
    /// 原始消息显示状态绑定
    @Binding var showRawMessage: Bool

    var body: some View {
        AppIconButton(
            systemImage: showRawMessage ? "text.bubble.fill" : "curlybraces",
            tint: DesignTokens.Color.semantic.textSecondary.opacity(0.6),
            size: .compact
        ) {
            showRawMessage.toggle()
        }
        .help(showRawMessage ? String(localized: "Show Rendered", comment: "Toggle to show rendered markdown") : String(localized: "Show Source", comment: "Toggle to show markdown source"))
    }
}
