import LumiKernel
import LumiUI
import SwiftUI

/// ActivityBar 错误视图
///
/// 当 `kernel.workspace` 为 `nil`（即工作区服务 `WorkspaceProviding` 不可用）时
/// 显示在 ActivityBar 主体位置的错误图标按钮。点击后通过 popover 展示错误详情，
/// 提示用户工作区服务未能加载。
///
/// 视觉上与 `StatusBarErrorView` 保持一致：使用 `@LumiTheme.theme.error` 主题色。
/// 但 `StatusBar` 高度仅 24pt，无法承载 popover；`ActivityBar` 是 48pt 图标列，
/// 有空间承载 popover 交互，因此这里采用图标 + popover 的方案。
struct ActivityBarErrorView: View {
    @LumiTheme private var theme
    @State private var isPresented = false

    private let error: Error

    init(error: Error = LumiKernelError.serviceNotAvailable(service: "Workspace")) {
        self.error = error
    }

    var body: some View {
        Button {
            // 失焦后再弹出，避免输入态意外抢占焦点
            NSApp.keyWindow?.makeFirstResponder(nil)
            NSApp.mainWindow?.makeFirstResponder(nil)
            isPresented.toggle()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(theme.error)
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Workspace unavailable")
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            popoverContent
        }
    }

    // MARK: - Popover

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.error)
                Text("Workspace Error")
                    .font(.appBodyEmphasized)
                    .foregroundStyle(theme.textPrimary)
            }

            Text(error.localizedDescription)
                .font(.appCallout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Please restart the app or check the logs for more details.")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        .frame(width: 240)
    }
}

// MARK: - 预览

#if DEBUG
    #Preview("ActivityBarErrorView") {
        ActivityBarErrorView()
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.15))
    }

    #Preview("ActivityBarErrorView - Custom Error") {
        ActivityBarErrorView(
            error: LumiKernelError.serviceNotAvailable(service: "LayoutManager")
        )
        .frame(width: 48)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
    }
#endif
