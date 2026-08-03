import LumiUI
import SwiftUI

struct OnboardingAppWindow: View {
    let isSettingsHighlighted: Bool
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            AppToolbarContainer(
                height: 28,
                padding: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
            ) {
                HStack(spacing: 6) {
                    Circle().fill(.red.opacity(0.7)).frame(width: 7, height: 7)
                    Circle().fill(.yellow.opacity(0.7)).frame(width: 7, height: 7)
                    Circle().fill(.green.opacity(0.7)).frame(width: 7, height: 7)
                    Text(text("Lumi"))
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.leading, 6)
                    Spacer()
                }
            }

            HStack(spacing: 0) {
                OnboardingActivityBar(isSettingsHighlighted: isSettingsHighlighted)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.appTitle)
                            .foregroundStyle(theme.primary)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(text("Welcome to Lumi"))
                                .font(.appBodyEmphasized)
                            Text(text("Your AI-powered desktop assistant"))
                                .font(.appCaption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    AppCard(
                        style: .subtle,
                        cornerRadius: DesignTokens.Radius.sm,
                        padding: DesignTokens.Spacing.compactPadding,
                        showShadow: false
                    ) {
                        Text(text("Start a conversation or open Settings to customize Lumi"))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .appSurface(style: .panel, cornerRadius: 0)
            }
        }
        .appSurface(style: .panel, cornerRadius: DesignTokens.Radius.md)
        .appClipRounded(DesignTokens.Radius.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func text(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview("App Window") {
    OnboardingAppWindow(isSettingsHighlighted: false)
        .frame(width: 520, height: 238)
        .padding()
}
