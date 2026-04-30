import Foundation

@MainActor
final class SampleDecorationContributor: EditorDecorationContributor {
    let id = "sample.decoration.gutter"

    func provideGutterDecorations(
        context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        guard !context.isLargeFileMode,
              let content = state.content?.string,
              !content.isEmpty else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }

        let renderRange = context.renderLineRange.clamped(to: 0..<lines.count)
        guard !renderRange.isEmpty else { return [] }

        var suggestions: [EditorGutterDecorationSuggestion] = []

        for lineIndex in renderRange {
            let lineText = lines[lineIndex]
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("TODO") {
                suggestions.append(
                    EditorGutterDecorationSuggestion(
                        id: "sample.todo.\(lineIndex)",
                        line: lineIndex,
                        lane: 1,
                        kind: .custom(name: "todo", tone: .warning, symbolName: "checklist"),
                        priority: 80,
                        badgeText: "TODO"
                    )
                )
            }

            if trimmed.contains("FIXME") {
                suggestions.append(
                    EditorGutterDecorationSuggestion(
                        id: "sample.fixme.\(lineIndex)",
                        line: lineIndex,
                        lane: 1,
                        kind: .custom(name: "fixme", tone: .error, symbolName: "wrench.and.screwdriver"),
                        priority: 90,
                        badgeText: "FIXME"
                    )
                )
            }

            if lineIndex == context.currentLine {
                suggestions.append(
                    EditorGutterDecorationSuggestion(
                        id: "sample.current-line.\(lineIndex)",
                        line: lineIndex,
                        lane: 2,
                        kind: .gitChange(.modified),
                        priority: 40,
                        badgeText: "Demo"
                    )
                )
            }
        }

        return suggestions
    }
}

private extension Range<Int> {
    func clamped(to bounds: Range<Int>) -> Range<Int> {
        let lower = Swift.max(lowerBound, bounds.lowerBound)
        let upper = Swift.min(upperBound, bounds.upperBound)
        guard lower < upper else { return lower..<lower }
        return lower..<upper
    }
}
