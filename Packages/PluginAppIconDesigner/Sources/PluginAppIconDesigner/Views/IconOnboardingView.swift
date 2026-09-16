import LumiUI
import SwiftUI

/// App Icon 设计器的首次使用引导。
struct IconOnboardingView: View {
    let isProjectOpen: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PluginOnboardingPageView(
                    icon: "app.dashed",
                    displayName: L("App Icon Designer"),
                    description: L("Design app icons and export multiple sizes."),
                    features: [
                        .init(
                            icon: "text.bubble",
                            title: L("AI Operations"),
                            description: L("Ask the Agent to create, style, and revise an icon document.")
                        ),
                        .init(
                            icon: "folder",
                            title: L("In Project"),
                            description: L("In Project: stored with the current project and available only to it.")
                        ),
                        .init(
                            icon: "square.stack.3d.up",
                            title: L("Layered vectors"),
                            description: L("Build icons from shapes, symbols, text, fills, strokes, and effects.")
                        ),
                        .init(
                            icon: "square.and.arrow.down",
                            title: L("Xcode Export"),
                            description: L("Export SVG artwork or an Xcode AppIcon set when the design is ready.")
                        ),
                    ],
                    tip: isProjectOpen
                        ? L("In Project: stored with the current project and available only to it.")
                        : L("Open a project to enable project-local storage.")
                )

                LandingSection(title: L("Creating an Icon"), icon: "list.number") {
                    LandingStepFlow(steps: [
                        .init(
                            title: L("Open a project to enable project-local storage."),
                            description: L("Icon documents are stored with the current project."),
                            icon: "folder"
                        ),
                        .init(
                            title: L("Ask the Agent to create or load an icon document."),
                            description: L("Describe the icon you want in the conversation."),
                            icon: "text.bubble"
                        ),
                        .init(
                            title: L("Review and iterate on the generated icon."),
                            description: L("Refine colors, shapes, layers, and composition in the conversation."),
                            icon: "eye"
                        ),
                        .init(
                            title: L("Export the finished asset."),
                            description: L("Export SVG or an Xcode AppIcon set when the design is ready."),
                            icon: "square.and.arrow.down"
                        ),
                    ])
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func L(_ key: String) -> String {
        AppIconDesignerLocalization.string(key)
    }
}

#Preview {
    IconOnboardingView(isProjectOpen: true)
        .frame(width: 760, height: 760)
}
