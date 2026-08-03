import LumiUI
import SwiftUI

struct OnboardingSettingsWindow: View {
    let showsPluginManager: Bool
    let showsEnabled: Bool
    let isPluginClick: Bool

    @LumiTheme private var theme

    var body: some View {
        AppSettingsSidebarShell {
            AppSettingsSidebarContainer(width: 132) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(text("Settings"))
                        .font(.appBodyEmphasized)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.bottom, DesignTokens.Spacing.xs)

                    sidebarRow("slider.horizontal.3", "General", false)
                    sidebarRow("puzzlepiece.extension", "Plugins", showsPluginManager)
                    sidebarRow("paintbrush", "Appearance", false)
                    Spacer()
                }
                .padding(DesignTokens.Spacing.sm)
            }
        } detail: {
            AppSettingsDetailPane {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(text("Plugin Manager"))
                        .font(.appTitle)
                    Text(text("Enable the tools you want to use"))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)

                    OnboardingPluginRow(
                        name: text("Git"),
                        icon: "arrow.triangle.branch",
                        enabled: showsEnabled,
                        highlighted: isPluginClick,
                        reportsToggleTarget: true
                    )
                    OnboardingPluginRow(
                        name: text("Project Files"),
                        icon: "doc.text",
                        enabled: false,
                        highlighted: false
                    )
                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .appSurface(style: .panel, cornerRadius: DesignTokens.Radius.md)
        .appClipRounded(DesignTokens.Radius.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sidebarRow(_ icon: String, _ key: String, _ isSelected: Bool) -> some View {
        let row = AppSettingsSidebarItem(
            title: text(key),
            systemImage: icon,
            isSelected: isSelected
        ) {}
        .font(.appCaption)
        .animation(.easeInOut(duration: 0.35), value: isSelected)

        if isSelected {
            row.reportsOnboardingTarget(.plugins)
        } else {
            row
        }
    }

    private func text(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview("Settings Window") {
    OnboardingSettingsWindow(showsPluginManager: true, showsEnabled: true, isPluginClick: true)
        .frame(width: 520, height: 238)
        .padding()
}
