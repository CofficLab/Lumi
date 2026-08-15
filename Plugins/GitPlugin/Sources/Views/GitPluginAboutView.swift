import LumiUI
import SwiftUI

/// Git 插件关于视图 —— 以「历史、差异与工具」为主轴的落地页。
struct GitPluginAboutView: View {
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
            icon: "arrow.triangle.branch",
            accent: theme.success,
            tagline: L("Explore history, diffs, branches and commits — with six Git tools in the sidebar."),
            chips: [L("History"), L("Branches"), L("Diff"), L("Commit")],
            metrics: [
                .init(value: "7", label: L("Agent tools")),
                .init(value: "6", label: L("Git tools")),
                .init(value: "2", label: L("Sidebar tabs"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "clock", tint: theme.info,
                      title: L("Commit History"),
                      description: L("Browse commits with relative dates, authors and statistics.")),
                .init(icon: "plus.forwardslash.minus", tint: theme.warning,
                      title: L("Diff Review"),
                      description: L("Inspect additions and deletions of any commit or file.")),
                .init(icon: "arrow.triangle.branch", tint: theme.primary,
                      title: L("Branch Management"),
                      description: L("Create, switch and manage branches.")),
                .init(icon: "tray.full", tint: theme.success,
                      title: L("Stash"),
                      description: L("Save and restore uncommitted changes.")),
                .init(icon: "eye.slash", tint: theme.warning,
                      title: L(".gitignore"),
                      description: L("View and edit the ignore rules of the repository.")),
                .init(icon: "externaldrive", tint: theme.info,
                      title: L("Git LFS"),
                      description: L("Track and fetch large files.")),
                .init(icon: "square.stack.3d.down.right", tint: theme.primary,
                      title: L("Submodules"),
                      description: L("Manage nested repositories.")),
                .init(icon: "arrow.up.circle", tint: theme.success,
                      title: L("Auto Push"),
                      description: L("Push commits automatically after committing."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.success, items: [
                .init(icon: "clock",
                      title: L("Git history panel in the sidebar")),
                .init(icon: "wrench.and.screwdriver",
                      title: L("Tools panel with six utilities")),
                .init(icon: "menubar.rectangle",
                      title: L("Stash, .gitignore and LFS status bar tiles"))
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
        GitPluginAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
