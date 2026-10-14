import LumiUI
import SwiftUI

/// Port Manager 插件关于视图
struct PortManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "arrow.up.arrow.down.circle",
                accent: theme.info,
                tagline: L("Inspect local listening ports and identify which apps are using them."),
                chips: [L("Port Monitor"), L("Process Info"), L("Real-time")],
                metrics: [
                    .init(value: "1", label: L("View")),
                    .init(value: L("实时"), label: L("刷新")),
                    .init(value: "0", label: L("额外配置"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "list.bullet.rectangle", tint: theme.info,
                          title: L("Port List"),
                          description: L("View all active listening ports on your machine.")),
                    .init(icon: "app", tint: theme.primary,
                          title: L("Process Info"),
                          description: L("See which process is bound to each port.")),
                    .init(icon: "arrow.triangle.2.circlepath", tint: theme.success,
                          title: L("Real-time Refresh"),
                          description: L("Port status updates automatically as services start and stop."))
                ])
            }
            .landingAppear(delay: 0.05)
        }
    }

    private func L(_ key: String) -> String {
        key
    }
}

#Preview {
    ScrollView {
        PortManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
