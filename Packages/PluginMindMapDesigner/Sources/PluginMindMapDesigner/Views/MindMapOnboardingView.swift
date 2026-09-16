import LumiUI
import SwiftUI

/// 思维导图设计器首次使用引导。
struct MindMapOnboardingView: View {
    let isProjectOpen: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PluginOnboardingPageView(
                    icon: "brain.head.profile",
                    displayName: L("Mind Map Designer"),
                    description: L("Create and edit mind maps."),
                    features: [
                        .init(
                            icon: "text.bubble",
                            title: L("Agent-driven maps"),
                            description: L("Ask the Agent to turn a topic or outline into a mind map.")
                        ),
                        .init(
                            icon: "folder",
                            title: L("In Project"),
                            description: L("Mind maps are stored with the current project and available only to it.")
                        ),
                        .init(
                            icon: "pencil.and.outline",
                            title: L("Canvas editing"),
                            description: L("Grow branches, edit labels, and reorganize the tree directly on the canvas.")
                        ),
                        .init(
                            icon: "arrow.down.doc",
                            title: L("Markdown export"),
                            description: L("Export a readable outline or the complete JSON document when ready.")
                        ),
                    ],
                    tip: isProjectOpen
                        ? L("Mind maps are stored in the current project.")
                        : L("Open a project to enable project-local storage.")
                )

                LandingSection(title: L("Creating a Mind Map"), icon: "list.number") {
                    LandingStepFlow(steps: [
                        .init(
                            title: L("Open a project to enable project-local storage."),
                            description: L("Mind maps are stored in the current project's .lumi folder."),
                            icon: "folder"
                        ),
                        .init(
                            title: L("Ask the Agent to create a mind map."),
                            description: L("Describe a topic, planning problem, or Markdown outline in the conversation."),
                            icon: "text.bubble"
                        ),
                        .init(
                            title: L("Review and grow the branches."),
                            description: L("Select a node to add a child or sibling, or edit its text inline."),
                            icon: "arrow.triangle.branch"
                        ),
                        .init(
                            title: L("Export the finished outline."),
                            description: L("Use the bottom toolbar to export Markdown or JSON."),
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
        MindMapLocalization.string(key)
    }
}

#Preview {
    MindMapOnboardingView(isProjectOpen: true)
        .frame(width: 760, height: 760)
}
