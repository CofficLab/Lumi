import Foundation
import SwiftUI

@MainActor
final class SampleInsightsSettingsContributor: SuperEditorSettingsContributor {
    let id = "sample.insights.settings"

    func provideSettingsItems(state: EditorSettingsState) -> [EditorSettingsItemSuggestion] {
        [
            EditorSettingsItemSuggestion(
                id: "sample.insights.inline-tips",
                sectionTitle: "扩展设置",
                sectionSummary: "来自 editor extensions 的设置项会自动汇总到这个分组。",
                title: "Sample Insights Inline Tips",
                subtitle: "控制样例插件是否显示额外说明文案。",
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
    static let shared = SampleInsightsSettingsStore()
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

    var body: some View {
        GlassRow {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Insights Inline Tips")
                        .font(.system(size: 15, weight: .medium))
                    Text("用于演示插件贡献设置如何统一显示在 editor settings 页面。")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
                }

                Spacer()

                Toggle("", isOn: $store.inlineTipsEnabled)
                    .labelsHidden()
            }
        }
    }
}
