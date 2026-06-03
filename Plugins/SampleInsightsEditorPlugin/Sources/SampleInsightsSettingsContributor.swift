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
                sectionTitle: String(localized: "Extension Settings", bundle: .module),
                sectionSummary: String(localized: "Settings items from editor extensions are automatically grouped here.", bundle: .module),
                title: String(localized: "Sample Insights Inline Tips", bundle: .module),
                subtitle: String(localized: "Used to demonstrate how plugin settings are displayed in the editor settings page.", bundle: .module),
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
            String(localized: "Sample Insights Inline Tips", bundle: .module),
            description: String(localized: "Used to demonstrate how plugin settings are displayed in the editor settings page.", bundle: .module),
            isOn: $store.inlineTipsEnabled
        )
    }
}
