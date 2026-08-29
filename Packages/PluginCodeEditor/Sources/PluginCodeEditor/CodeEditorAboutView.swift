import LumiUI
import SwiftUI

/// Code Editor 插件关于页。
struct CodeEditorAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "chevron.left.forwardslash.chevron.right",
                accent: theme.primary,
                tagline: L("Display and edit the file currently selected in the project Explorer."),
                chips: [L("Current File"), L("Syntax Highlighting"), L("Editing"), L("Save")],
                metrics: [
                    .init(value: "1", label: L("Current File")),
                    .init(value: "Cmd+S", label: L("Save")),
                    .init(value: "VS Code", label: L("Experience"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: "doc.text",
                        tint: theme.primary,
                        title: L("Current File"),
                        description: L("The editor follows the file selected in the project Explorer.")),
                    .init(
                        icon: "paintbrush",
                        tint: theme.info,
                        title: L("Syntax Highlighting"),
                        description: L("The shared editor surface detects the file language and highlights source code.")),
                    .init(
                        icon: "pencil.line",
                        tint: theme.warning,
                        title: L("Edit and Save"),
                        description: L("Edit text directly in the editor and save changes with Cmd+S."))
                ])
            }
            .landingAppear(delay: 0.05)
        }
    }

    private func L(_ key: String) -> String {
        CodeEditorLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        CodeEditorAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 760)
}
