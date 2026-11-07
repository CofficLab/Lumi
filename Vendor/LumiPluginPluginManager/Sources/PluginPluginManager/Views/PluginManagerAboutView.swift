import LumiUI
import SwiftUI

/// 插件管理器关于视图 —— Landing 落地页（复刻旧版 `PluginManagerAboutView`）。
///
/// 当前阶段仅展示；布局与视觉对齐旧版：Hero 横幅 + 核心能力分区 + 入口位置分区。
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
            tagline: PluginPluginManagerText.aboutDescription,
            chips: [PluginPluginManagerText.searchPlugins, PluginPluginManagerText.allCategories],
            metrics: [
                .init(value: PluginPluginManagerText.enabled, label: PluginPluginManagerText.enabledCount),
                .init(value: PluginPluginManagerText.alwaysOn, label: PluginPluginManagerText.policyLabel)
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: PluginPluginManagerText.coreCapabilities, icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.grid.2x2", tint: theme.primary,
                      title: PluginPluginManagerText.capabilityCatalogTitle,
                      description: PluginPluginManagerText.capabilityCatalogDescription),
                .init(icon: "magnifyingglass", tint: theme.info,
                      title: PluginPluginManagerText.capabilitySearchTitle,
                      description: PluginPluginManagerText.capabilitySearchDescription),
                .init(icon: "folder", tint: theme.warning,
                      title: PluginPluginManagerText.capabilityFilterTitle,
                      description: PluginPluginManagerText.capabilityFilterDescription),
                .init(icon: "info.circle", tint: theme.info,
                      title: PluginPluginManagerText.capabilityDetailTitle,
                      description: PluginPluginManagerText.capabilityDetailDescription),
                .init(icon: "arrow.up.arrow.down", tint: theme.primary,
                      title: PluginPluginManagerText.capabilityOrderTitle,
                      description: PluginPluginManagerText.capabilityOrderDescription)
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: PluginPluginManagerText.whereToFindIt, icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "gearshape", title: PluginPluginManagerText.settingsEntry)
            ])
        }
        .landingAppear(delay: 0.1)
    }
}

#Preview("关于视图") {
    ScrollView {
        PluginManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
