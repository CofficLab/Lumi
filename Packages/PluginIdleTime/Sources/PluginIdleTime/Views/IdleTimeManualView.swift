import LumiUI
import SwiftUI

/// Idle Time 插件使用手册
struct IdleTimeManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Idle Time"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers Idle Time detection, which monitors your Mac's input activity to infer rest windows and active patterns."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Menu Bar"))
            ManualBulletList(items: [
                .init(L("Menu bar icon: shows current idle state and confidence level.")),
                .init(L("Click to view the popover with recent activity patterns and rest window estimate.")),
            ])

            ManualSectionHeader(number: 3, title: L("Settings Panel"))
            ManualBulletList(items: [
                .init(L("Activity timeline: a strip chart showing recent activity events.")),
                .init(L("Rest window: the predicted time range when you typically stop working.")),
                .init(L("Confidence: how certain the model is about the predicted rest window.")),
            ])

            ManualSectionHeader(number: 4, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Idle Time runs automatically in the background once enabled.")),
                .init(L("Click the menu bar icon to check current idle status and recent patterns.")),
                .init(L("Open Settings → Idle Time to view the detailed activity dashboard.")),
                .init(L("The system learns your patterns over several days of normal use.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("All activity data is stored locally and never leaves your device.")),
                .init(L("Accuracy improves over time as more data is collected.")),
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
        IdleTimeManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
