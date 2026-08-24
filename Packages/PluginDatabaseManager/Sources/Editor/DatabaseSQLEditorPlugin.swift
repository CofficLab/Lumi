import Foundation
import EditorContracts
import TreeSitterSQL

enum DatabaseSQLLanguageSupport {
    static let descriptor = KernelEditorLanguageDescriptor(
        languageId: "sql",
        displayName: "SQL",
        fileExtensions: ["sql"],
        lineComment: "--",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "sql",
        lspLanguageId: nil
    )
}


final class DatabaseSQLGrammarProvider: KernelLanguageGrammarProviding {
    let grammarId = "sql"

    func treeSitterLanguage() -> OpaquePointer? {
        tree_sitter_sql()
    }

    func highlightQueryURLs() -> [URL] {
        Bundle.module.url(
            forResource: "highlights",
            withExtension: "scm",
            subdirectory: "tree-sitter-sql"
        ).map { [$0] } ?? []
    }
}
