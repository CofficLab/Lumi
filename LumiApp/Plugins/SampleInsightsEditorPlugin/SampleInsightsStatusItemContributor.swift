import Foundation
import SwiftUI
import MagicKit

@MainActor
final class SampleInsightsStatusItemContributor: SuperEditorStatusItemContributor {
    let id = "sample.insights.status-item"

    func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion] {
        [
            EditorStatusItemSuggestion(
                id: "sample.insights.title-toggle",
                order: 200,
                placement: .titleTrailing,
                metadata: .init(
                    priority: 20,
                    dedupeKey: "sample-insights-toggle",
                    isEnabled: { $0.isEditorActive }
                ),
                content: { sampleState in
                    AnyView(SampleInsightsStatusItemView(state: sampleState))
                }
            )
        ]
    }
}

private struct SampleInsightsStatusItemView: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var store = SampleInsightsPanelStore.shared

    var body: some View {
        Button {
            store.isPresented.toggle()
            state.objectWillChange.send()
        } label: {
            Label(String(localized: "Insights", table: "SampleInsights"), systemImage: store.isPresented ? "lightbulb.max.fill" : "lightbulb.max")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(store.isPresented ? Color(hex: "7C6FFF").opacity(0.12) : Color(hex: "98989E").opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .help(String(localized: "Toggle sample insights panel", table: "SampleInsights"))
    }
}
