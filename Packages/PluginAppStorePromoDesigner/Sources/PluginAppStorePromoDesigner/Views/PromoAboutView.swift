import LumiUI
import SwiftUI

/// App Store 推广图插件关于视图 —— Landing 落地页。
public struct PromoAboutView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "photo.artframe",
            accent: theme.info,
            tagline: L("Agent-generated HTML promotional artwork with exact App Store export sizes."),
            chips: [L("Multi-language"), L("Exact sizes"), L("HTML")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "photo.stack", tint: theme.info,
                      title: L("Promo Artwork"),
                      description: L("Create promotional images from a natural-language brief.")),
                .init(icon: "textformat", tint: theme.primary,
                      title: L("Multi-language"),
                      description: L("Independent localized versions of every artwork.")),
                .init(icon: "square.and.arrow.down", tint: theme.success,
                      title: L("Exact Export Sizes"),
                      description: L("Render at precise App Store display sizes.")),
                .init(icon: "paintbrush.pointed", tint: theme.warning,
                      title: L("Senior Design Review"),
                      description: L("Structured critique with concrete revision suggestions."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Promo tab in the sidebar"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PromoLocalization.string(key)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        PromoAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
