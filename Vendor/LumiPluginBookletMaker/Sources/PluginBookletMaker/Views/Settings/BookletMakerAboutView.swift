import LumiUI
import SwiftUI

// MARK: - Booklet Maker About View

/// Booklet Maker 关于视图 —— Landing 落地页。
struct BookletMakerAboutView: View {
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
            icon: "book.closed",
            accent: theme.info,
            tagline: L("Booklet pages are reordered for folding and binding; print a test sheet first."),
            chips: [L("Booklet"), L("Duplex"), L("Booklet Fold")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.richtext", tint: theme.primary,
                      title: L("Booklet Maker"),
                      description: L("Duplex imposition and binding")),
                .init(icon: "book.pages", tint: theme.info,
                      title: L("Booklet Fold"),
                      description: L("Booklet pages are reordered for folding and binding; print a test sheet first.")),
                .init(icon: "printer", tint: theme.success,
                      title: L("Output paper"),
                      description: L("Choose the output paper size and the layout, such as Booklet Fold or Simple Pair.")),
                .init(icon: "scissors", tint: theme.warning,
                      title: L("Split PDF"),
                      description: L("Split after specified pages"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Booklet Maker tab in the sidebar")),
                .init(icon: "gearshape",
                      title: L("Settings → Booklet Maker"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        BookletLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        BookletMakerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
