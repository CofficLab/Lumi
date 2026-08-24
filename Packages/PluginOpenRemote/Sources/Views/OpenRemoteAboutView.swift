import LumiUI
import SwiftUI

/// Open Remote 插件关于视图 —— Landing 落地页。
public struct OpenRemoteAboutView: View {
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
            icon: "arrow.up.right.square",
            accent: theme.success,
            tagline: L("Open the current project's remote repository in your browser."),
            chips: [L("One click"), L("Browser")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "arrow.up.right.square", tint: theme.success,
                      title: L("Open Remote"),
                      description: L("Jump from the project to its hosted repository.")),
                .init(icon: "lanyardcard", tint: theme.info,
                      title: L("Header Button"),
                      description: L("A dedicated button lives in the title bar.")),
                .init(icon: "arrow.triangle.branch", tint: theme.primary,
                      title: L("Repo Detection"),
                      description: L("Reads the project's remote automatically."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.success, items: [
                .init(icon: "macwindow",
                      title: L("Header toolbar button"))
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
        OpenRemoteAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
