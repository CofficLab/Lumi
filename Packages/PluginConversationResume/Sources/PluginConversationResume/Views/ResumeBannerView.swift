import LumiUI
import SwiftUI

/// 聊天底部的「继续」提示条。
///
/// 位置：消息列表下方、输入框上方（`ChatSectionItem.placement == .bottomFixed`）。
///
/// 出现条件：当前会话的上一轮在执行中被异常中断（崩溃 / 强杀），
/// 判定逻辑见 `ResumeEligibility`。
struct ResumeBannerView: View {
    @ObservedObject var viewModel: ResumeViewModel
    @LumiTheme private var theme

    var body: some View {
        Group {
            if viewModel.isResumable {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.appBody)
                        .foregroundStyle(theme.warning)

                    Text(Self.interruptedText)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    AppButton(
                        Self.resumeTitle,
                        systemImage: "play.fill",
                        style: .primary,
                        size: .small
                    ) {
                        viewModel.resume()
                    }
                    .disabled(viewModel.isResuming)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .appSurface(style: .panel, cornerRadius: 0)
            }
        }
    }

    // MARK: - 文案

    private static let resumeTitle = pluginLocalization.string("Continue")

    /// 提示正文。
    ///
    /// 判定理由（`ResumeCoordinator.State.reason`）是给日志看的，
    /// 不适合直接展示给用户，因此展示固定的说明文案。
    private static let interruptedText = pluginLocalization.string(
        "The previous run was interrupted. You can continue."
    )
}

#if DEBUG
#Preview("Resume Banner") {
    ResumeBannerView(viewModel: ResumeViewModel(performResume: {}))
        .frame(width: 480)
}
#endif
