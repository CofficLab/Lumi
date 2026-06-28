import Foundation
import LumiCoreKit
import SwiftUI

public enum ActivityHeatmapPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.activity-heatmap",
        displayName: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
        description: LumiPluginLocalization.string("Show conversation activity heatmap in settings", bundle: .module),
        order: 60
    )
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "chart.bar.fill"

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        guard let historyService = context.resolve((any HistoryQueryService).self) else {
            return nil
        }

        return AnyView(
            ActivityHeatmapSettingsView(historyService: historyService)
        )
    }
}
