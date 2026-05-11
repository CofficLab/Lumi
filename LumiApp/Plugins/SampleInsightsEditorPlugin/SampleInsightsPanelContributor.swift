import Foundation
import SwiftUI

@MainActor
final class SampleInsightsPanelContributor: SuperEditorPanelContributor {
    let id = "sample.insights.panel"

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        [
            EditorPanelSuggestion(
                id: "sample.insights.side-panel",
                title: String(localized: "Sample Insights", table: "SampleInsights"),
                systemImage: "lightbulb.max",
                placement: .bottom,
                order: -10,
                metadata: .init(priority: 100, dedupeKey: "sample-insights-panel"),
                isPresented: { sampleState in
                    SampleInsightsPanelStore.shared.isPresented && sampleState.currentFileURL != nil
                },
                onDismiss: { sampleState in
                    SampleInsightsPanelStore.shared.isPresented = false
                    sampleState.objectWillChange.send()
                },
                content: { sampleState in
                    AnyView(SampleInsightsPanelView(state: sampleState))
                }
            )
        ]
    }
}

@MainActor
final class SampleInsightsPanelStore: ObservableObject {
    static let shared = SampleInsightsPanelStore()

    @Published var isPresented = false

    private init() {}
}

private struct SampleInsightsPanelView: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var store = SampleInsightsPanelStore.shared

    private var fileSummary: String {
        state.currentFileURL?.lastPathComponent ?? "No File"
    }

    private var languageSummary: String {
        state.detectedLanguage?.tsName ?? state.fileExtension ?? "plain"
    }

    private var todoSummary: (todo: Int, fixme: Int) {
        guard let content = state.content?.string else { return (0, 0) }
        let lines = content.components(separatedBy: .newlines)
        return lines.reduce(into: (0, 0)) { partial, line in
            if line.contains("TODO") { partial.0 += 1 }
            if line.contains("FIXME") { partial.1 += 1 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Sample Insights", table: "SampleInsights"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(fileSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Button(String(localized: "Close", table: "SampleInsights")) {
                    store.isPresented = false
                    state.objectWillChange.send()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
            }

            insightRow(String(localized: "Language", table: "SampleInsights"), languageSummary)
            insightRow(String(localized: "Cursor", table: "SampleInsights"), "Ln \(max(state.cursorLine, 1)), Col \(max(state.cursorColumn, 1))")
            insightRow("TODO", "\(todoSummary.todo)")
            insightRow("FIXME", "\(todoSummary.fixme)")
            insightRow(String(localized: "Large File", table: "SampleInsights"), state.largeFileMode == .normal ? String(localized: "No", table: "SampleInsights") : String(localized: "Yes", table: "SampleInsights"))

            Text(String(localized: "This panel is contributed by SuperEditorPanelContributor and toggled from a titleTrailing status item.", table: "SampleInsights"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 280, alignment: .topLeading)
    }

    private func insightRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
        }
    }
}
