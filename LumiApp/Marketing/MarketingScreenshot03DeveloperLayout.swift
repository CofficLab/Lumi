import SwiftUI

struct MarketingScreenshot03DeveloperLayout: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "Developer Layout",
            title: "Editor, search and terminal in one view",
            subtitle: "Use rails, tabs, breadcrumbs and bottom panels without switching away from the current file."
        ) {
            MarketingMacWindow {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        MarketingActivityBar(selected: "chevron.left.forwardslash.chevron.right")
                        MarketingRail(mode: .search)
                        MarketingEditorPanel(fileName: "RemoteProviderSettingsView.swift", showBottomPanel: true)
                    }
                    MarketingStatusBar()
                }
            }
        }
    }
}

#Preview("03 Developer Layout") {
    MarketingScreenshot03DeveloperLayout()
}
