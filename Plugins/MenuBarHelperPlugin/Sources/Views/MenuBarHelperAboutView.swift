import LumiUI
import SwiftUI

// MARK: - Menu Bar Helper About View

/// Menu Bar Helper 关于视图 —— Landing 落地页。
struct MenuBarHelperAboutView: View {
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
            icon: "menubar.rectangle",
            accent: theme.warning,
            tagline: L("Manage which menu bar items are visible in the macOS menu bar."),
            chips: [L("Menu bar"), L("Visibility")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "menubar.rectangle", tint: theme.warning,
                      title: L("Item Visibility"),
                      description: L("Show or hide menu bar items from one settings UI.")),
                .init(icon: "switch.2", tint: theme.info,
                      title: L("Per-item Toggles"),
                      description: L("Independent on/off control for every item.")),
                .init(icon: "arrow.clockwise", tint: theme.success,
                      title: L("Instant Apply"),
                      description: L("Changes apply immediately without restarting."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "gearshape",
                      title: L("Settings → Menu Bar"))
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
        MenuBarHelperAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
