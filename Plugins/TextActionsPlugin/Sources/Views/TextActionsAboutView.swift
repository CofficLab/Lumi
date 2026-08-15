import LumiUI
import SwiftUI

/// 文本操作插件关于视图 —— Landing 落地页。
struct TextActionsAboutView: View {
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
            icon: "text.badge.checkmark",
            accent: theme.info,
            tagline: L("Quick text manipulation actions on selected text."),
            chips: [L("Copy"), L("Search"), L("Translate")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.on.doc", tint: theme.success,
                      title: L("Copy"),
                      description: L("Copy the selected text instantly.")),
                .init(icon: "magnifyingglass", tint: theme.info,
                      title: L("Search"),
                      description: L("Search for the selected text on the web.")),
                .init(icon: "character.bubble", tint: theme.primary,
                      title: L("Translate"),
                      description: L("Translate the selected text.")),
                .init(icon: "cursorarrow.rays", tint: theme.warning,
                      title: L("Floating Menu"),
                      description: L("A menu appears right at the selection.")),
                .init(icon: "switch.2", tint: theme.info,
                      title: L("Enable Switch"),
                      description: L("Turn the floating menu on or off.")),
                .init(icon: "lock.shield", tint: theme.success,
                      title: L("Accessibility"),
                      description: L("Reads selection via accessibility permission."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Text Actions tab in the sidebar")),
                .init(icon: "gearshape",
                      title: L("Settings → Text Actions"))
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
        TextActionsAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
