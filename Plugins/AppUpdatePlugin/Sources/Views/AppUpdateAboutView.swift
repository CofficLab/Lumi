import LumiUI
import SwiftUI

/// App Update 插件关于视图 —— Landing 落地页。
struct AppUpdateAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "arrow.down.circle",
            accent: theme.success,
            tagline: L("Integrates Sparkle to check for and install app updates automatically."),
            chips: [L("Auto-check"), L("Auto-install")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "arrow.down.circle", tint: theme.success,
                      title: L("Automatic Updates"),
                      description: L("Check for new versions in the background.")),
                .init(icon: "sparkles", tint: theme.info,
                      title: L("Seamless Install"),
                      description: L("Download and apply updates with Sparkle.")),
                .init(icon: "bell", tint: theme.warning,
                      title: L("Update Notices"),
                      description: L("Surface update availability when found."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.success, items: [
                .init(icon: "gearshape",
                      title: L("Settings → General → Updates"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        AppUpdateAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
