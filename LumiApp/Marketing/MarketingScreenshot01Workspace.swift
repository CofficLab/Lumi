import SwiftUI

struct MarketingScreenshot01Workspace: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "AI Coding Workspace",
            title: "Build inside one focused Mac workspace",
            subtitle: "Code, project files, agent chat and status tools stay visible in a native desktop layout."
        ) {
            MarketingMacWindow {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        MarketingActivityBar(selected: "chevron.left.forwardslash.chevron.right")
                        MarketingRail(mode: .files)
                        MarketingEditorPanel(fileName: "ContentView.swift")
                        MarketingAgentSidebar()
                    }
                    MarketingStatusBar()
                }
            }
        }
    }
}

#Preview("01 Workspace") {
    MarketingScreenshot01Workspace()
}
