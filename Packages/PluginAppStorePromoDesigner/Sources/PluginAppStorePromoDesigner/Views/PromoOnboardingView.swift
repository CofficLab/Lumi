import LumiUI
import SwiftUI

/// App Store 宣传图设计器的首次使用引导。
///
/// 没有宣传图任务时显示在主区域，帮助用户理解项目内存储、Agent 创作、
/// 预览修改和导出的完整流程。
struct PromoOnboardingView: View {
    let isProjectOpen: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PluginOnboardingPageView(
                    icon: "photo.artframe",
                    displayName: L("App Store Promo Designer"),
                    description: L("Agent-generated HTML promotional artwork with exact App Store export sizes."),
                    features: [
                        .init(
                            icon: "text.bubble",
                            title: L("Promo Artwork"),
                            description: L("Create promotional images from a natural-language brief.")
                        ),
                        .init(
                            icon: "folder",
                            title: L("In Project"),
                            description: L("In Project: stored with the current project and available only to it.")
                        ),
                        .init(
                            icon: "photo.on.rectangle",
                            title: L("Editing Content"),
                            description: L("State changes in the conversation, such as copy, colors, or layout.")
                        ),
                        .init(
                            icon: "square.and.arrow.down",
                            title: L("Exact Export Sizes"),
                            description: L("Render at precise App Store display sizes.")
                        ),
                    ],
                    tip: isProjectOpen
                        ? L("In Project: stored with the current project and available only to it.")
                        : L("Open a project to enable project-local storage.")
                )

                LandingSection(title: L("Creating a Promo Image"), icon: "list.number") {
                    LandingStepFlow(steps: [
                        .init(
                            title: L("Open a project to enable project-local storage."),
                            description: L("In Project: stored with the current project and available only to it."),
                            icon: "folder"
                        ),
                        .init(
                            title: L("Ask the Agent to create a promotional artwork task."),
                            description: L("Create promotional images from a natural-language brief."),
                            icon: "text.bubble"
                        ),
                        .init(
                            title: L("Review the generated image in the preview."),
                            description: L("In Preview mode, right-click the headline or the screenshot area to draft an edit request for that block."),
                            icon: "eye"
                        ),
                        .init(
                            title: L("Select a display size in the toolbar."),
                            description: L("Images are exported as PNGs at the selected size, grouped into folders by language."),
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
        PromoLocalization.string(key)
    }
}

#Preview {
    PromoOnboardingView(isProjectOpen: true)
        .frame(width: 760, height: 760)
}
