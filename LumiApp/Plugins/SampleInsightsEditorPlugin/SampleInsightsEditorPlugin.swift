import Foundation

/// 编辑器 hover / panel 样例插件：演示统一 hover content 与 panel contribution point。
actor SampleInsightsEditorPlugin: SuperPlugin {
    static let id = "SampleInsightsEditor"
    static let displayName = "Sample Insights"
    static let description = "Demonstrates hover, panel, and title action contributions."
    static let iconName = "lightbulb.max"
    static let order = 91
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHoverContentContributor(SampleInsightsHoverContributor())
        registry.registerPanelContributor(SampleInsightsPanelContributor())
        registry.registerStatusItemContributor(SampleInsightsStatusItemContributor())
    }
}
