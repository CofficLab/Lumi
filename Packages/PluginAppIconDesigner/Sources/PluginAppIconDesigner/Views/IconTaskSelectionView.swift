import LumiUI
import SwiftUI

/// 有任务但尚未选中时的主面板：用一组图标卡片说明插件用途，再给出下一步引导。
struct IconTaskSelectionView: View {
    let message: String

    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            IconArtworkShowcase()

            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 24, height: 24)

                Text(message)
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2, style: .continuous)
                    .fill(theme.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2, style: .continuous)
                    .strokeBorder(theme.primary.opacity(0.16), lineWidth: 1)
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct IconArtworkShowcase: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovering = false

    private var motionIsActive: Bool {
        isHovering && motionPreference.allowsMotion
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(theme.textSecondary.opacity(0.08))
                .frame(width: 340, height: 220)
                .rotationEffect(.degrees(-6))
                .offset(x: -22, y: 16)
                .scaleEffect(motionIsActive ? 1.02 : 1)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.info, theme.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 340, height: 220)
                .rotationEffect(.degrees(5))
                .offset(x: 23, y: 13)
                .shadow(color: theme.primary.opacity(0.16), radius: 16, y: 10)
                .scaleEffect(motionIsActive ? 1.02 : 1)

            AppCard(
                style: .elevated,
                cornerRadius: DesignTokens.Radius.lg,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                showShadow: true
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .fill(theme.primaryGradient)

                    Circle()
                        .fill(theme.info.opacity(0.32))
                        .frame(width: 190, height: 190)
                        .blur(radius: 12)
                        .offset(x: 135, y: -75)

                    Circle()
                        .fill(theme.primarySecondary.opacity(0.34))
                        .frame(width: 160, height: 160)
                        .blur(radius: 16)
                        .offset(x: -125, y: 94)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("APP ICON")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)

                            Spacer(minLength: 0)

                            Image(systemName: "app.dashed")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.88))

                        Spacer(minLength: 0)

                        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.md) {
                            Text("ICON")
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(-1.8)

                            Spacer(minLength: 0)

                            IconMiniPreview()
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
                .frame(width: 370, height: 236)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            }
            .offset(y: motionIsActive ? -7 : 0)
            .rotationEffect(.degrees(motionIsActive ? 0 : 2))
            .shadow(
                color: theme.primary.opacity(motionIsActive ? 0.24 : 0.16),
                radius: motionIsActive ? 24 : 16,
                y: motionIsActive ? 18 : 11
            )
        }
        .frame(width: 440, height: 270)
        .onHover { hovering in
            if motionPreference.allowsMotion {
                withAnimation(.easeOut(duration: 0.45)) {
                    isHovering = hovering
                }
            } else {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppIconDesignerLocalization.string("App Icon Designer"))
    }
}

private struct IconMiniPreview: View {
    @LumiTheme private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.18))
            .frame(width: 116, height: 116)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primarySecondary, theme.info],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(12)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 31, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 8)
    }
}

#Preview("Task Selection") {
    IconTaskSelectionView(
        message: AppIconDesignerLocalization.string(
            "Select an icon document from the left, or ask the Agent to create one."
        )
    )
    .frame(width: 560, height: 560)
}
