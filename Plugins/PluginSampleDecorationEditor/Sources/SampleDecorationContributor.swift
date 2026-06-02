import Foundation
import EditorService

@MainActor
public final class SampleDecorationContributor: SuperEditorDecorationContributor {
    public let id = "sample.decoration.gutter"

    public func provideGutterDecorations(
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
            let markers = SampleDecorationMarkerDetector.markers(in: lineText)

            if markers.contains(.todo) {
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

            if markers.contains(.fixme) {
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

enum SampleDecorationMarker: Hashable {
    case todo
    case fixme
}

enum SampleDecorationMarkerDetector {
    static func markers(in line: String) -> Set<SampleDecorationMarker> {
        guard let comment = commentFragment(in: line) else { return [] }

        var markers: Set<SampleDecorationMarker> = []
        if containsMarker("TODO", in: comment) {
            markers.insert(.todo)
        }
        if containsMarker("FIXME", in: comment) {
            markers.insert(.fixme)
        }
        return markers
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

private extension Range<Int> {
    func clamped(to bounds: Range<Int>) -> Range<Int> {
        let lower = Swift.max(lowerBound, bounds.lowerBound)
        let upper = Swift.min(upperBound, bounds.upperBound)
        guard lower < upper else { return lower..<lower }
        return lower..<upper
    }
}
