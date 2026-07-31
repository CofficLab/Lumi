import LumiUI
import SwiftUI

/// 状态栏错误视图
///
/// 当工作区服务（WorkspaceProviding）不可用时显示错误提示。
///
/// 高度仅 24pt(状态栏标准行高),不适合使用 `AppErrorBanner`(那是带 padding 的
/// 大尺寸横幅)。这里保留紧凑布局,但颜色一律走 `@LumiTheme`(`theme.error` /
/// `theme.warning`),与设置界面等服务不可用态观感一致。
struct StatusBarErrorView: View {
    @LumiTheme private var theme

    let message: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.error)
            Text(message)
                .foregroundColor(theme.error)
                .lineLimit(1)
            Spacer()
            Text("⚠️ Service Error")
                .foregroundColor(theme.warning)
                .lineLimit(1)
        }
        .font(.appCaption)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(isHovered ? theme.error.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Workspace service is not registered. Please ensure WorkspacePlugin is loaded.")
    }
}
