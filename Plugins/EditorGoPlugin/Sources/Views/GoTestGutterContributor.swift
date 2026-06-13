import Foundation
import EditorService


@MainActor
public final class GoTestGutterContributor: SuperEditorGutterDecorationContributor {
    public let id = "go.test-gutter"

    public func provideGutterDecorations(
        context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        guard context.languageId == "go",
              let content = state.content?.string,
              !context.isLargeFileMode else {
            return []
        }

        return GoCodeLensPipeline.lenses(in: content, languageId: context.languageId)
            .map(\.line)
            .filter { context.renderLineRange.contains($0) }
            .map { line in
            EditorGutterDecorationSuggestion(
                id: "go-test-\(line)",
                line: line,
                lane: 1,
                kind: .custom(name: "go-test", tone: .success, symbolName: "play.fill"),
                priority: 10
            )
        }
    }

    public static func testLineNumbers(in content: String, range: Range<Int>) -> [Int] {
        GoCodeLensPipeline.lenses(in: content, languageId: "go")
            .map(\.line)
            .filter { range.contains($0) }
    }
}
