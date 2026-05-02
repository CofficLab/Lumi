import Foundation
import SwiftUI

@MainActor
final class SampleInsightsPanelContributor: SuperEditorPanelContributor {
    let id = "sample.insights.panel"

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        [
            EditorPanelSuggestion(
                id: "sample.insights.side-panel",
                title: "Sample Insights",
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
                    Text("Sample Insights")
                        .font(.system(size: 13, weight: .semibold))
                    Text(fileSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Button("Close") {
                    store.isPresented = false
                    state.objectWillChange.send()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
            }

            insightRow("Language", languageSummary)
            insightRow("Cursor", "Ln \(max(state.cursorLine, 1)), Col \(max(state.cursorColumn, 1))")
            insightRow("TODO", "\(todoSummary.todo)")
            insightRow("FIXME", "\(todoSummary.fixme)")
            insightRow("Large File", state.largeFileMode == .normal ? "No" : "Yes")

            Text("This panel is contributed by `SuperEditorPanelContributor` and toggled from a `titleTrailing` status item.")
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
