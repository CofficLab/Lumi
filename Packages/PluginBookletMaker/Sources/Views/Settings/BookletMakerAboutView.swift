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
            tagline: L("Turn PDFs into 2-up imposition ready for A4 duplex printing, folding and stapling."),
            chips: [L("2-up"), L("Duplex"), L("A4")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.richtext", tint: theme.primary,
                      title: L("PDF Import"),
                      description: L("Load any PDF and lay out its pages two-up.")),
                .init(icon: "book.pages", tint: theme.info,
                      title: L("Imposition"),
                      description: L("Simple Pair and Booklet Fold layout modes.")),
                .init(icon: "printer", tint: theme.success,
                      title: L("Duplex Ready"),
                      description: L("Front and back sheets for A4 double-sided printing.")),
                .init(icon: "scissors", tint: theme.warning,
                      title: L("Fold & Staple"),
                      description: L("Order pages so they fold into a stapled booklet."))
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
