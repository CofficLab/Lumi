import LumiUI
import ProviderToast
import SwiftUI

// MARK: - Toast Overlay

/// 挂在主窗口根部的 Toast 渲染覆盖层。
///
/// 订阅共享的 `ToastCenter`（即 `ToastProviding` 实现），在窗口顶部
/// 渲染当前 toast；持久化错误则以居中面板呈现。
/// Toast 本身不参与交互（`allowsHitTesting(false)`），不遮挡下方内容。
/// 具体视觉由 LumiUI 组件承担（见 `ToastBannerView` / `ErrorNoticeOverlay`）。
public struct ToastOverlay<Content: View>: View {
    private let content: Content
    @ObservedObject private var center: ToastCenter
    @LumiMotionPreferenceReader private var motionPreference
    @Environment(\.toastWindowID) private var windowID
    #if os(macOS)
        @Environment(\.controlActiveState) private var activeState
    #endif

    public init(content: Content, center: ToastCenter) {
        self.content = content
        self.center = center
    }

    /// 错误面板只在一个窗口显示：
    /// - 带来源窗口标识：仅在来源窗口渲染；
    /// - 无来源：macOS 上仅在当前活动（key）窗口兜底渲染，iOS 单场景直接渲染。
    private func shouldDisplayError(_ error: LumiErrorNotice) -> Bool {
        if let source = error.sourceWindowID {
            return source == windowID
        }
        #if os(macOS)
            return activeState == .key
        #else
            return true
        #endif
    }

    public var body: some View {
        content
            .overlay(alignment: .top) {
                Group {
                    if let toast = center.currentToast {
                        ToastBannerView(toast: toast)
                            .appStatusPresentationTransition(preference: motionPreference)
                    } else if let loading = center.currentLoading {
                        AppStatusBanner(
                            kind: .loading,
                            title: loading.title,
                            message: loading.detail
                        )
                        .frame(maxWidth: 380, alignment: .leading)
                        .appShadow(.xl)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.sm)
                        .appStatusPresentationTransition(preference: motionPreference)
                    }
                }
                .animation(
                    LumiMotion.enabled(LumiMotion.statusPresentation, preference: motionPreference),
                    value: center.currentToast
                )
                .animation(
                    LumiMotion.enabled(LumiMotion.statusPresentation, preference: motionPreference),
                    value: center.currentLoading
                )
                .allowsHitTesting(false)
            }
            .overlay {
                if let error = center.currentError, shouldDisplayError(error) {
                    ErrorNoticeOverlay(error: error, center: center)
                }
            }
    }
}

// MARK: - Preview

@MainActor
private struct ToastOverlayPreviewHost: View {
    private let center: ToastCenter

    init(style: LumiToastStyle, detail: String?) {
        let center = ToastCenter()
        center.show(
            LumiToast(
                title: "Commit selected",
                detail: detail,
                style: style,
                // 预览中保持常驻，避免自动消失后预览空白。
                duration: 3600
            )
        )
        self.center = center
    }

    var body: some View {
        ToastOverlay(content: Color.lumiControlBackground, center: center)
    }
}

#Preview("App - Large") {
    ToastOverlayPreviewHost(style: .info, detail: "a1b2c3d")
        .inRootView()
        .frame(width: 600, height: 400)
}

#Preview("App - Small") {
    ToastOverlayPreviewHost(style: .success, detail: nil)
        .inRootView()
        .frame(width: 360, height: 300)
}
