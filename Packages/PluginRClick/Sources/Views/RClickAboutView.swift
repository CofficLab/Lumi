import LumiUI
import SwiftUI

/// 右键菜单插件关于视图 —— Landing 落地页。
struct RClickAboutView: View {
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
            icon: "cursorarrow.click.2",
            accent: theme.warning,
            tagline: L("Right-click context menu actions in Finder."),
            chips: [L("Finder"), L("Context menu"), L("New File")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "cursorarrow.click.2", tint: theme.warning,
                      title: L("Context Actions"),
                      description: L("Extra actions in the Finder right-click menu.")),
                .init(icon: "doc.badge.plus", tint: theme.success,
                      title: L("New File Menu"),
                      description: L("Create files from user-defined templates.")),
                .init(icon: "puzzlepiece.extension", tint: theme.info,
                      title: L("Finder Extension"),
                      description: L("A macOS extension enabled from System Settings.")),
                .init(icon: "plus.square.on.square", tint: theme.primary,
                      title: L("Templates"),
                      description: L("Define name, extension and default content.")),
                .init(icon: "eye", tint: theme.info,
                      title: L("Live Preview"),
                      description: L("Preview the resulting right-click menu.")),
                .init(icon: "arrow.counterclockwise", tint: theme.error,
                      title: L("Reset"),
                      description: L("Restore actions and templates to defaults."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "sidebar.left",
                      title: L("Right Click tab in the sidebar")),
                .init(icon: "gearshape",
                      title: L("Settings → Right Click"))
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
        RClickAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
