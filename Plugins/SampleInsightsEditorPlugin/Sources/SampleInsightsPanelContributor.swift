import Foundation
import EditorService
import SwiftUI

@MainActor
public final class SampleInsightsPanelContributor: SuperEditorPanelContributor {
    public let id = "sample.insights.panel"

    public func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        [
            EditorPanelSuggestion(
                id: "sample.insights.side-panel",
                title: String(localized: "Sample Insights", bundle: .module),
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
public final class SampleInsightsPanelStore: ObservableObject {
    public static let shared = SampleInsightsPanelStore()

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
        return SampleInsightsMarkerCounter.countMarkers(in: content)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Sample Insights", bundle: .module))
                        .font(.system(size: 13, weight: .semibold))
                    Text(fileSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Button(String(localized: "Close", bundle: .module)) {
                    store.isPresented = false
                    state.objectWillChange.send()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
            }

            insightRow(String(localized: "Language", bundle: .module), languageSummary)
            insightRow(String(localized: "Cursor", bundle: .module), "Ln \(max(state.cursorLine, 1)), Col \(max(state.cursorColumn, 1))")
            insightRow("TODO", "\(todoSummary.todo)")
            insightRow("FIXME", "\(todoSummary.fixme)")
            insightRow(String(localized: "Large File", bundle: .module), state.largeFileMode == .normal ? String(localized: "No", bundle: .module) : String(localized: "Yes", bundle: .module))

            Text(String(localized: "This panel is contributed by SuperEditorPanelContributor and toggled from a titleTrailing status item.", bundle: .module))
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

enum SampleInsightsMarkerCounter {
    static func countMarkers(in content: String) -> (todo: Int, fixme: Int) {
        let lines = content.components(separatedBy: .newlines)
        return lines.reduce(into: (0, 0)) { partial, line in
            guard let comment = commentFragment(in: line) else { return }
            if containsMarker("TODO", in: comment) { partial.0 += 1 }
            if containsMarker("FIXME", in: comment) { partial.1 += 1 }
        }
    }

    private static func commentFragment(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("*") {
            return trimmed
        }

        let markers = ["//", "#", "/*", "<!--"]
        let ranges = markers.compactMap { marker in
            line.range(of: marker).map { $0 }
        }

        guard let first = ranges.min(by: { $0.lowerBound < $1.lowerBound }) else {
            return nil
        }

        return String(line[first.lowerBound...])
    }

    private static func containsMarker(_ marker: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while let range = text.range(of: marker, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
            let hasValidPrefix = range.lowerBound == text.startIndex
                || !isMarkerCharacter(text[text.index(before: range.lowerBound)])
            let hasValidSuffix = range.upperBound == text.endIndex
                || !isMarkerCharacter(text[range.upperBound])

            if hasValidPrefix && hasValidSuffix {
                return true
            }

            searchStart = range.upperBound
        }

        return false
    }

    private static func isMarkerCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
