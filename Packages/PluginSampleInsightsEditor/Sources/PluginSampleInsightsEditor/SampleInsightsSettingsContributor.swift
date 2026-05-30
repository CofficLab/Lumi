import LumiUI
import Foundation
import EditorService
import SwiftUI

@MainActor
public final class SampleInsightsSettingsContributor: SuperEditorSettingsContributor {
    public let id = "sample.insights.settings"

    public func provideSettingsItems(state: EditorSettingsState) -> [EditorSettingsItemSuggestion] {
        [
            EditorSettingsItemSuggestion(
                id: "sample.insights.inline-tips",
                sectionTitle: String(localized: "Extension Settings", table: "SampleInsights"),
                sectionSummary: String(localized: "Settings items from editor extensions are automatically grouped here.", table: "SampleInsights"),
                title: String(localized: "Sample Insights Inline Tips", table: "SampleInsights"),
                subtitle: String(localized: "Used to demonstrate how plugin settings are displayed in the editor settings page.", table: "SampleInsights"),
                keywords: ["sample insights", "extension", "tips", "插件设置"],
                order: 10,
                metadata: .init(priority: 40, dedupeKey: "sample-insights-inline-tips"),
                content: { _ in
                    AnyView(SampleInsightsSettingsToggleRow())
                }
            )
        ]
    }
}

@MainActor
private final class SampleInsightsSettingsStore: ObservableObject {
    public static let shared = SampleInsightsSettingsStore()
    private let inlineTipsKey = "sampleInsights.inlineTipsEnabled"

    @Published var inlineTipsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(inlineTipsEnabled, forKey: inlineTipsKey)
        }
    }

    private init() {
        inlineTipsEnabled = UserDefaults.standard.object(forKey: inlineTipsKey) as? Bool ?? true
    }
}

private struct SampleInsightsSettingsToggleRow: View {
    @ObservedObject private var store = SampleInsightsSettingsStore.shared

    public var body: some View {
        AppSettingsToggleRow(
            String(localized: "Sample Insights Inline Tips", table: "SampleInsights"),
            description: String(localized: "Used to demonstrate how plugin settings are displayed in the editor settings page.", table: "SampleInsights"),
            isOn: $store.inlineTipsEnabled
        )
    }
}
