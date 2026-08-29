import LumiUI
import SwiftUI

/// Quick Launcher 插件关于视图
struct QuickLauncherAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "bolt.fill",
                accent: theme.primary,
                tagline: L("Open apps, files and Lumi commands from a global hotkey."),
                chips: [L("Global Hotkey"), L("App Search"), L("File Search"), L("Commands")],
                metrics: [
                    .init(value: "1", label: L("Hotkey")),
                    .init(value: "3", label: L("Search Sources")),
                    .init(value: "0", label: L("Extra Config"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "app", tint: theme.primary,
                          title: L("App Launcher"),
                          description: L("Search and open installed applications instantly.")),
                    .init(icon: "doc", tint: theme.info,
                          title: L("File Search"),
                          description: L("Find files in your project with fuzzy matching.")),
                    .init(icon: "command", tint: theme.warning,
                          title: L("Command Palette"),
                          description: L("Access all Lumi commands from the launcher.")),
                    .init(icon: "questionmark.circle", tint: theme.success,
                          title: L("Ask AI"),
                          description: L("Type ? followed by a question to send it directly to the AI."))
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
        QuickLauncherAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
