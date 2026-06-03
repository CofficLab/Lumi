import LumiUI
import SwiftUI

// MARK: - Raw Message Toggle Button

/// 原始消息切换按钮
/// 用于在原始 Markdown 源码和渲染视图之间切换
public struct RawMessageToggleButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 原始消息显示状态绑定
    @Binding var showRawMessage: Bool

    public var body: some View {
        AppIconButton(
            systemImage: showRawMessage ? "text.bubble.fill" : "curlybraces",
            tint: theme.textSecondary.opacity(0.6),
            size: .compact
        ) {
            showRawMessage.toggle()
        }
        .help(showRawMessage ? String(localized: "Show Rendered", bundle: .module, comment: "Toggle to show rendered markdown") : String(localized: "Show Source", bundle: .module, comment: "Toggle to show markdown source"))
    }
}
