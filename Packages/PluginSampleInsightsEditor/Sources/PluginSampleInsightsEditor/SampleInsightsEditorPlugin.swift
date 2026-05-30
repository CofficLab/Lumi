import Foundation
import EditorService
import LumiCoreKit

/// 编辑器 hover / panel 样例插件：演示统一 hover content 与 panel contribution point。
public actor SampleInsightsEditorPlugin: SuperPlugin {
    public static let shared = SampleInsightsEditorPlugin()
    public static let id = "SampleInsightsEditor"
    public static let displayName = String(localized: "Sample Insights", table: "SampleInsights")
    public static let description = String(localized: "Demonstrates hover, panel, and title action contributions.", table: "SampleInsights")
    public static let iconName = "lightbulb.max"
    public static let order = 91
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHoverContentContributor(SampleInsightsHoverContributor())
        registry.registerPanelContributor(SampleInsightsPanelContributor())
        registry.registerSettingsContributor(SampleInsightsSettingsContributor())
        registry.registerStatusItemContributor(SampleInsightsStatusItemContributor())
    }
}
