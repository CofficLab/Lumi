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
    public static func addSettingsView(context: LumiPluginContext) -> [AnyView] {
        guard let historyService = context.resolve((any HistoryQueryService).self) else {
            return []
        }

        return [AnyView(ActivityHeatmapSettingsView(historyService: historyService))]
    }

    @MainActor
    public static func addSettingsTabs(context: LumiPluginContext) -> [LumiSettingsTabItem] {
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
}
