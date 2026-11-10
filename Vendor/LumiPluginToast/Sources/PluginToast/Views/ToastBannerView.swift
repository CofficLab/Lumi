import LumiUI
import ProviderToast
import SwiftUI

// MARK: - Toast Banner View

/// 单条 Toast 的视觉呈现。
///
/// 直接复用 LumiUI 的 `AppStatusBanner`：图标、色调、「标题 + 说明」排版与
/// 圆角面板都由 LumiUI 统一决定，本视图只负责映射风格与窗口顶部的定位、
/// 阴影和宽度约束。
struct ToastBannerView: View {
    private let toast: LumiToast

    init(toast: LumiToast) {
        self.toast = toast
    }

    var body: some View {
        AppStatusBanner(
            kind: toast.style.statusBannerKind,
            title: toast.title,
            message: toast.detail
        )
        .frame(maxWidth: 380, alignment: .leading)
        .appShadow(.xl)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.sm)
    }
}

// MARK: - LumiToastStyle Extensions

extension LumiToastStyle {
    /// 映射到 LumiUI `AppStatusBanner` 的状态种类（决定图标与强调色）。
    var statusBannerKind: AppStatusBanner.Kind {
        switch self {
        case .info: .info
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }
}

// MARK: - Preview

#Preview("App - Large") {
    ToastBannerView(
        toast: LumiToast(title: "Commit selected", detail: "a1b2c3d", style: .info)
    )
    .inRootView()
    .frame(width: 600, height: 200)
}

#Preview("App - Small") {
    ToastBannerView(toast: LumiToast(title: "Commit selection cleared", style: .warning))
        .inRootView()
        .frame(width: 360, height: 160)
}
