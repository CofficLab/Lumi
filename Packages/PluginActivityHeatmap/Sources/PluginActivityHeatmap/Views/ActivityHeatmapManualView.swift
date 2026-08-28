import LumiUI
import SwiftUI

/// Activity Heatmap 插件使用手册
struct ActivityHeatmapManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Activity Heatmap"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Activity Heatmap, which visualizes your daily conversation activity and token consumption over time."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Settings Panel"))
            ManualBulletList(items: [
                .init(L("Period selector: choose Last 30 days, Last 90 days, or Last year to adjust the time range.")),
                .init(L("Summary metrics: total messages, active days, and total tokens are shown at the top.")),
                .init(L("Heatmap grid: each cell represents a day; darker colors indicate higher message activity.")),
                .init(L("Token trend chart: shows daily token consumption as a line chart below the heatmap.")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open Settings → Activity Heatmap to view the dashboard.")),
                .init(L("Select a time period using the picker at the top right.")),
                .init(L("Click the refresh button to reload the latest data.")),
                .init(L("Hover over any cell in the heatmap to see detailed counts for that day.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Data is cached locally and refreshed automatically when new messages arrive.")),
                .init(L("Token counts are only available when message-level token tracking is enabled.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        ActivityHeatmapManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
