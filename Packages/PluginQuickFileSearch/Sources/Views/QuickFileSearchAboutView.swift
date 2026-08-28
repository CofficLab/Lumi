import LumiUI
import SwiftUI

/// Quick File Search 插件关于视图
struct QuickFileSearchAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "magnifyingglass",
                accent: theme.primary,
                tagline: L("Search and open project files with Cmd+P."),
                chips: [L("Fuzzy Search"), L("Global Hotkey"), L("File Preview")],
                metrics: [
                    .init(value: "1", label: L("Hotkey")),
                    .init(value: "Cmd+P", label: L("Default")),
                    .init(value: "0", label: L("Extra Config"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "magnifyingglass", tint: theme.primary,
                          title: L("Fuzzy Search"),
                          description: L("Find files instantly with fuzzy matching — type partial names to filter.")),
                    .init(icon: "keyboard", tint: theme.info,
                          title: L("Global Hotkey"),
                          description: L("Press Cmd+P anywhere in the app to open the file search overlay.")),
                    .init(icon: "doc.text", tint: theme.warning,
                          title: L("Quick Open"),
                          description: L("Select a file to open it immediately in the editor."))
                ])
            }
            .landingAppear(delay: 0.05)
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        QuickFileSearchAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
