import LumiUI
import ProviderToast
import SwiftUI

#if canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#endif

// MARK: - Persistent Error Notice

/// 持久化错误面板：保留完整信息，支持滚动、文本选择、复制与用户确认关闭。
///
/// 面板骨架、阴影、复制按钮与操作按钮全部由 LumiUI 组件与设计令牌绘制
/// （`appSurface` / `appShadow` / `ErrorIconView` / `AppDivider` /
/// `AppSectionLabel` / `CopyMessageButton` / `AppButton`），本视图只负责排版
/// 与业务动作（关闭错误通知）。
///
/// 尺寸策略：面板高度由**错误内容**决定，而不是由窗口高度决定。
/// 消息区使用固定的最大高度（`messageMaxHeight`）而不是 `maxHeight: .infinity`，
/// 避免 VStack 中唯一可伸展的子视图贪婪吸收全部剩余空间、把一行短错误
/// 撑成整屏高的空白面板。外层 `maxHeight` 只作为「不超出窗口」的上限约束。
struct ErrorNoticeOverlay: View {
    private let error: LumiErrorNotice
    @ObservedObject private var center: ToastCenter
    @LumiMotionPreferenceReader private var motionPreference

    init(error: LumiErrorNotice, center: ToastCenter) {
        self.error = error
        self.center = center
    }

    /// 面板宽度下限：保证标题、关闭按钮与底部按钮不拥挤。
    static let minPanelWidth: CGFloat = 300
    /// 面板宽度上限：避免超长消息把面板拉得过宽。
    static let maxPanelWidth: CGFloat = 620
    /// 消息区最大高度：超过后转为滚动，保证长错误不超出窗口。
    static let messageMaxHeight: CGFloat = 240
    /// 面板与窗口边缘的最小间距。
    static let windowMargin = DesignTokens.Spacing.lg

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - Self.windowMargin * 2
            let availableHeight = geo.size.height - Self.windowMargin * 2
            let panelWidth = Self.resolvedPanelWidth(for: error, availableWidth: availableWidth)

            ZStack {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .transition(.opacity)

                ErrorNoticePanel(error: error, width: panelWidth) {
                    center.dismissError()
                }
                    // 高度上限只用于保证不超出窗口；面板实际高度仍由内容决定。
                    .frame(maxHeight: availableHeight)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .zIndex(1)
        .animation(
            LumiMotion.enabled(LumiMotion.statusPresentation, preference: motionPreference),
            value: error.id
        )
    }

    /// 按错误文本的固有宽度决定面板宽度，并在窗口约束内收敛。
    ///
    /// 短错误（如单行 `unexpected EOF`）得到紧凑面板；长错误自动扩展到
    /// `maxPanelWidth` 并在消息区内滚动。
    static func resolvedPanelWidth(for error: LumiErrorNotice, availableWidth: CGFloat) -> CGFloat {
        let upperBound = min(Self.maxPanelWidth, availableWidth)
        let lowerBound = min(Self.minPanelWidth, upperBound)
        let contentWidth = intrinsicContentWidth(for: error)
        guard contentWidth > 0 else { return lowerBound }
        return min(upperBound, max(lowerBound, contentWidth))
    }

    /// 估算错误内容不换行时的固有宽度（消息与标题取较宽者）。
    static func intrinsicContentWidth(for error: LumiErrorNotice) -> CGFloat {
        let messageFont = PlatformFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let titleFont = PlatformFont.systemFont(ofSize: 20, weight: .semibold)

        let messageWidth = error.message
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { measuredWidth(of: String($0), font: messageFont) }
            .max() ?? 0
        let titleWidth = measuredWidth(of: error.title, font: titleFont)

        // 叠加消息区内边距与面板内边距，避免文字贴边。
        let horizontalInsets = DesignTokens.Spacing.sm * 2 + DesignTokens.Spacing.lg * 2
        return max(messageWidth, titleWidth) + horizontalInsets
    }

    /// 单行文本在给定字体下的像素宽度（跨平台实现）。
    private static func measuredWidth(of text: String, font: PlatformFont) -> CGFloat {
        #if canImport(AppKit)
        return (text as NSString).size(withAttributes: [.font: font]).width
        #else
        return (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).width
        #endif
    }
}

// MARK: - Panel

/// 错误面板本体：头部、错误详情、消息区与底部操作栏。
///
/// 独立成视图是为了让渲染尺寸可以被单独测量与回归测试覆盖。
struct ErrorNoticePanel: View {
    let error: LumiErrorNotice
    /// 面板宽度，由 `ErrorNoticeOverlay` 按内容与窗口约束算出。
    let width: CGFloat
    let onDismiss: () -> Void

    @LumiTheme private var theme
    @State private var showCopyFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            AppDivider()
                .padding(.vertical, DesignTokens.Spacing.md)

            AppSectionLabel(LumiPluginLocalization.string("Error details", bundle: .module))
                .padding(.bottom, DesignTokens.Spacing.xs)

            messageBox

            footer
        }
        .frame(width: width)
        .padding(DesignTokens.Spacing.lg)
        .appSurface(
            style: .panel,
            cornerRadius: DesignTokens.Radius.md,
            borderColor: theme.appSubtleBorder
        )
        .appShadow(.xxxl)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            ErrorIconView(size: 22, weight: .semibold)

            Text(error.title)
                .font(DesignTokens.Typography.title3)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: DesignTokens.Spacing.sm)

            // 标题栏关闭入口：面板变高时无需视线跨过整块消息区才能关闭。
            AppIconButton(
                systemImage: "xmark",
                label: LumiPluginLocalization.string("Close", bundle: .module)
            ) {
                onDismiss()
            }
            .accessibilityLabel(LumiPluginLocalization.string("Close", bundle: .module))
        }
    }

    private var messageBox: some View {
        ScrollView {
            Text(error.message)
                .font(DesignTokens.Typography.code)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.sm)
        }
        // 关键：使用固定上限而不是 `maxHeight: .infinity`。
        // 后者会让消息区贪婪吸收 VStack 的全部剩余空间，把一行短错误
        // 撑成接近整窗高的空白面板。短消息按内容自然收缩，长消息
        // 超过上限后转为滚动。
        .frame(maxHeight: ErrorNoticeOverlay.messageMaxHeight)
        .appSurface(
            style: .subtle,
            cornerRadius: DesignTokens.Radius.sm,
            borderColor: theme.appSubtleBorder
        )
    }

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            CopyMessageButton(content: error.message, showFeedback: $showCopyFeedback)

            Spacer()

            AppButton(
                LumiPluginLocalization.string("Close", bundle: .module),
                style: .primary
            ) {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
            .fixedSize()
        }
        .padding(.top, DesignTokens.Spacing.md)
    }
}

// MARK: - Preview

@MainActor
private struct ErrorNoticePreviewHost: View {
    private let center: ToastCenter

    init() {
        let center = ToastCenter()
        center.presentError(
            title: "Pull failed",
            message: "hint: You have divergent branches and need to specify how to reconcile them.\n"
                + "fatal: Need to specify how to reconcile divergent branches."
        )
        self.center = center
    }

    var body: some View {
        ErrorNoticeOverlay(error: center.currentError!, center: center)
    }
}

#Preview("App - Large") {
    ErrorNoticePreviewHost()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Small") {
    ErrorNoticePreviewHost()
        .inRootView()
        .frame(width: 520, height: 480)
}
