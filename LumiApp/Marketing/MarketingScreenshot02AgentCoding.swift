import SwiftUI

struct MarketingScreenshot02AgentCoding: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "Project-Aware Agent",
            title: "Ask Lumi to inspect and change real code",
            subtitle: "The assistant works beside your editor with file context, tool progress and concise results."
        ) {
            MarketingMacWindow {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        MarketingActivityBar(selected: "chevron.left.forwardslash.chevron.right")
                        MarketingRail(mode: .conversations)
                        MarketingEditorPanel(fileName: "AgentTurnService.swift")
                        MarketingAgentSidebar(focused: true)
                    }
                    MarketingStatusBar()
                }
            }
        }
    }
}

#Preview("02 Agent Coding") {
    MarketingScreenshot02AgentCoding()
}
