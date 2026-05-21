import Foundation

@MainActor
final class JSTestGutterContributor: SuperEditorGutterDecorationContributor {
    let id = "js.test-gutter"

    func provideGutterDecorations(
        context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        guard context.languageId == "javascript" || context.languageId == "typescript",
              let content = state.content?.string,
              !context.isLargeFileMode else {
            return []
        }

        return detectTestLines(in: content, range: context.renderLineRange).map { line in
            EditorGutterDecorationSuggestion(
                id: "js-test-\(line)",
                line: line,
                lane: 1,
                kind: .custom(name: "test", tone: .success, symbolName: "play.fill"),
                priority: 10,
                badgeText: nil
            )
        }
    }

    private func detectTestLines(in content: String, range: Range<Int>) -> [Int] {
        let names = ["test(", "it(", "describe("]
        return content.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            guard range.contains(index) else { return nil }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return names.contains(where: { trimmed.hasPrefix($0) || trimmed.contains(".\($0)") }) ? index : nil
        }
    }
}
