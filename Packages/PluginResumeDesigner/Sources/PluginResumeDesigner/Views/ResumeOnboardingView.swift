import LumiUI
import SwiftUI

/// 简历设计器的首次使用引导。
struct ResumeOnboardingView: View {
    let isProjectOpen: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PluginOnboardingPageView(
                    icon: "doc.badge.gearshape",
                    displayName: L("Resume Designer"),
                    description: L("Create and design a personal resume."),
                    features: [
                        .init(
                            icon: "text.bubble",
                            title: L("Agent-built resumes"),
                            description: L("Ask the Agent to create and revise a resume from a natural-language brief.")
                        ),
                        .init(
                            icon: "folder",
                            title: L("In Project"),
                            description: L("In Project: stored with the current project and available only to it.")
                        ),
                        .init(
                            icon: "doc.richtext",
                            title: L("HTML preview"),
                            description: L("Review the rendered page or inspect the complete HTML source." )
                        ),
                        .init(
                            icon: "square.and.arrow.down",
                            title: L("Print-ready export"),
                            description: L("Export PDF and PNG pages, or print the finished resume.")
                        ),
                    ],
                    tip: isProjectOpen
                        ? L("In Project: stored with the current project and available only to it.")
                        : L("Open a project to enable project-local storage.")
                )

                LandingSection(title: L("Creating a Resume"), icon: "list.number") {
                    LandingStepFlow(steps: [
                        .init(
                            title: L("Open a project to enable project-local storage."),
                            description: L("Resume documents are stored with the current project."),
                            icon: "folder"
                        ),
                        .init(
                            title: L("Ask the Agent to create a resume."),
                            description: L("Give the Agent your background, target role, and preferred style."),
                            icon: "text.bubble"
                        ),
                        .init(
                            title: L("Review and revise the page."),
                            description: L("Use Preview or Source, and click a content block to draft an edit request."),
                            icon: "eye"
                        ),
                        .init(
                            title: L("Export or print the finished resume."),
                            description: L("Choose PDF, PNG, or the system print flow from the bottom toolbar."),
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
        ResumeDesignerLocalization.string(key)
    }
}

#Preview {
    ResumeOnboardingView(isProjectOpen: true)
        .frame(width: 760, height: 760)
}
