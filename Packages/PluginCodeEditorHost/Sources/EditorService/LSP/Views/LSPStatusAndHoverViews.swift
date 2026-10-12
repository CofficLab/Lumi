import LumiUI
import SwiftUI

/// LSP Hover 简易提示浮层。
///
/// 用于展示一段纯文本 hover 内容。当前编辑器主流程更多使用 Markdown hover popover，
/// 该视图保留为 LSP 服务插件内的轻量展示组件。
public struct LSPHoverTooltip: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let content: String

    public var body: some View {
        Text(content)
            .font(.appMonoCaption)
            .foregroundColor(theme.textPrimary)
            .padding(8)
            .frame(maxWidth: 400, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 6, borderColor: theme.divider)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}
