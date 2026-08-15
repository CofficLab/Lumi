import LumiUI
import SwiftUI

/// 插件管理器关于视图 —— Landing 落地页。
struct PluginManagerAboutView: View {
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
            icon: "puzzlepiece.extension",
            accent: theme.primary,
            tagline: L("Lists and manages all plugins registered with the kernel."),
            chips: [L("Enable"), L("Disable"), L("Search")],
            metrics: [
                .init(value: L("Runtime"), label: L("toggle")),
                .init(value: L("Always On"), label: L("policy"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.grid.2x2", tint: theme.primary,
                      title: L("Plugin Catalog"),
                      description: L("Browse every registered plugin at a glance.")),
                .init(icon: "power", tint: theme.success,
                      title: L("Runtime Toggle"),
                      description: L("Enable or disable plugins without restarting.")),
                .init(icon: "magnifyingglass", tint: theme.info,
                      title: L("Search"),
                      description: L("Find plugins by name instantly.")),
                .init(icon: "folder", tint: theme.warning,
                      title: L("Category Filters"),
                      description: L("Filter by plugin category.")),
                .init(icon: "info.circle", tint: theme.info,
                      title: L("Plugin Details"),
                      description: L("Inspect each plugin's description and stage.")),
                .init(icon: "arrow.up.arrow.down", tint: theme.primary,
                      title: L("Ordering"),
                      description: L("Plugins sorted by registration order."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "gearshape",
                      title: L("Settings → Plugins"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PluginManagerText.string(key)
    }
}

#Preview {
    ScrollView {
        PluginManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
