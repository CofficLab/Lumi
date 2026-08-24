import LumiUI
import SwiftUI

/// 代码编辑器插件关于视图 —— Landing 落地页。
struct EditorPanelAboutView: View {
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
            icon: "doc.text.magnifyingglass",
            accent: theme.info,
            tagline: L("Display the content of the current project file."),
            chips: [L("Browse"), L("Edit")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.text", tint: theme.info,
                      title: L("File Viewer"),
                      description: L("Open and inspect any file of the current project.")),
                .init(icon: "sidebar.left", tint: theme.primary,
                      title: L("Project Sidebar"),
                      description: L("Navigate the project tree to find files.")),
                .init(icon: "square.and.pencil", tint: theme.success,
                      title: L("Inline Editing"),
                      description: L("Edit file content directly in the editor.")),
                .init(icon: "arrow.down.doc", tint: theme.warning,
                      title: L("Save Changes"),
                      description: L("Persist edits back to disk."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Editor in the rail, chat and panel"))
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
        EditorPanelAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
