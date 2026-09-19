import LumiUI
import SwiftUI

/// 原型设计器的首次使用引导。
///
/// 没有原型项目时显示在主区域，帮助用户理解「聊天创作 → 预览 → 迭代 → 导出」的流程。
struct PrototypeOnboardingView: View {
    let isProjectOpen: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PluginOnboardingPageView(
                    icon: "rectangle.on.rectangle.angled",
                    displayName: L("Prototype Designer"),
                    description: L("Chat with the Agent to sketch product prototypes as interactive HTML screens."),
                    features: [
                        .init(
                            icon: "text.bubble",
                            title: L("Describe a Screen"),
                            description: L("Describe the screen in words and the Agent writes the layout for you.")
                        ),
                        .init(
                            icon: "folder",
                            title: L("In Project"),
                            description: L("Prototypes are stored in the current project's .lumi directory.")
                        ),
                        .init(
                            icon: "arrow.turn.down.right",
                            title: L("Connected Screens"),
                            description: L("Screens link to each other so you can read the flow, not just single pictures.")
                        ),
                        .init(
                            icon: "square.and.arrow.down",
                            title: L("Exact Device Export"),
                            description: L("Render every screen as a PNG at the device's exact pixel size.")
                        ),
                    ],
                    tip: isProjectOpen
                        ? L("Prototypes are stored with the current project and available only to it.")
                        : L("Open a project to enable project-local storage.")
                )

                LandingSection(title: L("Creating a Prototype"), icon: "list.number") {
                    LandingStepFlow(steps: [
                        .init(
                            title: L("Open a project to enable project-local storage."),
                            description: L("Prototypes live in the project's .lumi/prototype directory."),
                            icon: "folder"
                        ),
                        .init(
                            title: L("Describe your product and the screens you need in the chat."),
                            description: L("The Agent picks a device canvas, then writes each screen's HTML."),
                            icon: "text.bubble"
                        ),
                        .init(
                            title: L("Review the rendered screen in the preview."),
                            description: L("Right-click a region to draft an edit request for that block."),
                            icon: "eye"
                        ),
                        .init(
                            title: L("Export when the flow reads correctly."),
                            description: L("Every screen is rendered as a PNG at the device's exact pixel size."),
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
        PrototypeLocalization.string(key)
    }
}

#Preview {
    PrototypeOnboardingView(isProjectOpen: true)
        .frame(width: 760, height: 760)
}
