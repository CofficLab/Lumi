import LumiUI
import SwiftUI

struct OnboardingActivityBar: View {
    let isSettingsHighlighted: Bool
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            AppActivityIconButton(
                systemImage: "bubble.left.and.bubble.right",
                label: text("Chat"),
                isActive: true
            ) {}
            
            AppActivityIconButton(systemImage: "folder", label: text("Projects")) {}

            Spacer()

            AppIconButton(
                systemImage: "gearshape",
                tint: isSettingsHighlighted ? theme.primary : nil,
                size: .regular,
                isActive: isSettingsHighlighted
            ) {}
            .reportsOnboardingTarget(.settings)
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func text(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview("Activity Bar") {
    OnboardingActivityBar(isSettingsHighlighted: true)
        .frame(width: 48, height: 220)
}
