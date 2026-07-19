import Foundation
import LumiCoreKit
import SwiftUI

public enum ActivityHeatmapPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.activity-heatmap",
        displayName: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
        description: LumiPluginLocalization.string("Show conversation activity heatmap in settings", bundle: .module),
        order: 60,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "chart.bar.fill",
    )

    @MainActor
    public static func addSettingsTabs(context: any LumiCoreAccessing) -> [LumiSettingsTabItem] {
        guard let historyService = context.resolve((any HistoryQueryService).self) else {
            return []
        }

        return [
            LumiSettingsTabItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                ActivityHeatmapSettingsView(historyService: historyService)
            }
        ]
    }

    @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: LumiPluginLocalization.string(
                    "Activity Heatmap 会把你与 Lumi 的协作对话绘制成日历热力图，让你一眼看到哪些日子活跃、哪些时段是高峰。",
                    bundle: .module
                ))
                .font(.appCaption)
                .foregroundStyle(.secondary)

                Divider()

                Label(
                    LumiPluginLocalization.string("数据来源：本地对话历史", bundle: .module),
                    systemImage: "lock.shield"
                )
                .font(.appMicro)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        )
    }
}
