import LumiUI
import LumiKernel
import SwiftUI

// MARK: - Error View

/// 错误状态视图。
///
/// 当 Homebrew 相关操作（环境检测、刷新、安装、卸载、更新等）
/// 出现错误时，使用本视图替换原本的原生 `.alert`，以保持与
/// 插件整体视觉风格一致。
///
/// 设计上参考 `BrewManagerEmptyView`：使用 `AppCard` 提供
/// 表面背景，通过 `LumiTheme` 适配明暗主题，提供关闭按钮
/// 和可选的"重试"按钮。
struct BrewManagerErrorView: View {
    /// 错误消息正文（可本地化）。
    let message: String

    /// 标题文本（可本地化）。
    var title: String = LumiPluginLocalization.string("Something went wrong", bundle: .module)

    /// 关闭按钮回调（必填）。
    let onDismiss: () -> Void

    /// 可选的重试按钮回调。
    ///
    /// 当提供此回调时，会渲染一个"重试"主按钮；
    /// 否则只显示"关闭"按钮。
    var onRetry: (() -> Void)? = nil

    @LumiTheme private var theme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            content
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    // MARK: - Content

    private var content: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 20,
            padding: EdgeInsets(top: 32, leading: 28, bottom: 32, trailing: 28)
        ) {
            VStack(spacing: 20) {
                iconBadge

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)

                    ScrollView {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 180)
                }

                VStack(spacing: 10) {
                    if let onRetry {
                        AppButton(
                            LocalizedStringKey("Retry"),
                            systemImage: "arrow.clockwise",
                            style: .primary,
                            fillsWidth: true,
                            action: onRetry
                        )
                    }

                    AppButton(
                        LocalizedStringKey("Dismiss"),
                        systemImage: "xmark",
                        style: .ghost,
                        fillsWidth: true,
                        action: onDismiss
                    )
                }
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: 440)
    }

    // MARK: - Icon Badge

    /// 圆形渐变徽章承载错误图标。
    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FF453A").opacity(0.18),
                            Color(hex: "FF453A").opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(Color(hex: "FF453A"))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Error · Dismiss Only") {
    BrewManagerErrorView(
        message: "Homebrew not detected, please install Homebrew first.",
        onDismiss: {}
    )
    .frame(width: 480, height: 480)
}

#Preview("Error · With Retry") {
    BrewManagerErrorView(
        message: "Refresh failed: Could not connect to Homebrew.",
        onDismiss: {},
        onRetry: {}
    )
    .frame(width: 480, height: 480)
}

#Preview("Error · Dark") {
    BrewManagerErrorView(
        message: "Search failed: Network timeout.",
        onDismiss: {},
        onRetry: {}
    )
    .frame(width: 480, height: 480)
    .environment(\.colorScheme, .dark)
}
