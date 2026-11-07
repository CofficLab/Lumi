#if os(macOS)
import LumiUI
import SwiftUI

/// 命令面板插件关于视图。
struct CommandAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "command",
                accent: theme.info,
                tagline: L("Every action, reachable from the keyboard."),
                chips: [L("⌘K"), L("Fuzzy"), L("Extensible")],
                metrics: [
                    .init(value: "1", label: L("shortcut")),
                    .init(value: "N", label: L("commands"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "keyboard", tint: theme.info,
                          title: L("Command Palette"),
                          description: L("Press the shortcut to open every command in one fuzzy list.")),
                    .init(icon: "puzzlepiece.extension", tint: theme.primary,
                          title: L("Plugin Extensible"),
                          description: L("Any plugin can register its own commands into the palette.")),
                    .init(icon: "text.magnifyingglass", tint: theme.warning,
                          title: L("Fuzzy Matching"),
                          description: L("Type a few letters and the best command rises to the top."))
                ])
            }
            .landingAppear(delay: 0.05)

            LandingSection(title: L("How It Works"), icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: L("Press ⌘K"), description: L("The palette opens over the workspace."), icon: "command"),
                    .init(title: L("Type & match"), description: L("Commands are fuzzy-matched against your input."), icon: "text.magnifyingglass"),
                    .init(title: L("Run"), description: L("Selecting a command triggers its plugin action."), icon: "bolt.fill")
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }
}

#Preview {
    ScrollView { CommandAboutView().padding(22) }
        .frame(width: 560, height: 900)
}
#endif
