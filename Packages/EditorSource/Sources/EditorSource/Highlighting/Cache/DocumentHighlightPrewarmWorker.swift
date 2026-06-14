import EditorLanguageRuntime
import Foundation
import SwiftTreeSitter

public enum DocumentHighlightPrewarmWorker {
    public static func buildSnapshot(
        fileURL: URL,
        content: String,
        language: EditorLanguageContext,
        highlightRevision: Int
    ) -> DocumentHighlightSnapshot? {
        guard let parserLanguage = LanguageRegistry.shared.treeSitterLanguage(for: language),
              let query = LanguageRegistry.shared.highlightQuery(for: language) else {
            return nil
        }

        do {
            let parser = Parser()
            try parser.setLanguage(parserLanguage)
            guard let syntaxTree = parser.parse(content) else {
                return nil
            }

            let queryCursor = query.execute(in: syntaxTree)
            var ranges: [NSRange: Int] = [:]
            let highlights: [HighlightRange] = queryCursor
                .resolve(with: .init(string: content))
                .flatMap { $0.captures }
                .reversed()
                .compactMap { capture in
                    let range = capture.range
                    let index = capture.index
                    if let existingLevel = ranges[range], existingLevel <= index {
                        return nil
                    }
                    guard let captureName = CaptureName.fromString(capture.name) else {
                        return nil
                    }
                    ranges[range] = index
                    return HighlightRange(range: range, capture: captureName)
                }

            guard !highlights.isEmpty else { return nil }

            let key = DocumentHighlightKey(
                fileURL: fileURL,
                content: content,
                languageId: language.languageId
            )
            return DocumentHighlightSnapshot(
                key: key,
                highlightRevision: highlightRevision,
                runs: highlights
            )
        } catch {
            return nil
        }
    }
}
