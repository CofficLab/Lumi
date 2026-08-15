import LumiUI
import SwiftUI

/// 设置插件关于视图 —— Landing 落地页。
struct SettingsAboutView: View {
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
            icon: "gearshape",
            accent: theme.primary,
            tagline: L("Provides the General and Appearance settings tabs."),
            chips: [L("General"), L("Appearance")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "gearshape", tint: theme.primary,
                      title: L("General Settings"),
                      description: L("Core preferences for how Lumi behaves.")),
                .init(icon: "paintpalette", tint: theme.info,
                      title: L("Appearance"),
                      description: L("Control the look and feel of the app.")),
                .init(icon: "sidebar.left", tint: theme.success,
                      title: L("Settings Tabs"),
                      description: L("Hosts the main settings surface."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "gearshape",
                      title: L("Settings window"))
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
        SettingsAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
