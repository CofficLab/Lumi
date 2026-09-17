import LumiUI
import SwiftUI

/// 有原型项目但尚未选中屏幕时的主面板：说明插件用途并给出下一步引导。
struct PrototypeSelectionView: View {
    let message: String

    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            PrototypeShowcase()

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

/// 三张并排的手机画板示意：表达「一个流程由多屏组成」。
private struct PrototypeShowcase: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(0..<3), id: \.self) { index in
                PhoneMock(index: index)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PrototypeLocalization.string("Prototype Designer"))
    }
}

/// 单张手机线框示意。
private struct PhoneMock: View {
    @LumiTheme private var theme
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .frame(width: 104, height: 196)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.appDivider, lineWidth: 1.5)
            }
            .overlay {
                VStack(spacing: 7) {
                    Capsule()
                        .fill(Color.primary.opacity(0.14))
                        .frame(width: 30, height: 4)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.primary.opacity(index == 1 ? 0.20 : 0.10))
                        .frame(height: index == 0 ? 46 : 34)

                    ForEach(Array(0..<(index == 1 ? 3 : 2)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                            .frame(height: 22)
                    }

                    Spacer(minLength: 0)

                    Capsule()
                        .fill(Color.primary.opacity(index == 2 ? 0.20 : 0.10))
                        .frame(height: 20)
                }
                .padding(9)
            }
            .rotationEffect(.degrees(index == 1 ? 0 : (index == 0 ? -4 : 4)))
            .offset(y: index == 1 ? -8 : 0)
            .shadow(
                color: Color.black.opacity(index == 1 ? 0.10 : 0.05),
                radius: index == 1 ? 14 : 8,
                y: index == 1 ? 10 : 6
            )
    }
}

#Preview("Selection") {
    PrototypeSelectionView(
        message: PrototypeLocalization.string(
            "Select a screen from the left, or ask the Agent to create a prototype."
        )
    )
    .frame(width: 560, height: 560)
}
