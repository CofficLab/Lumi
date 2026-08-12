import EditorLanguageRuntime
import Foundation
import LumiKernel
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

    static let context = EditorLanguageRuntime.EditorLanguageContext(
        descriptor: EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: "sql",
            displayName: "SQL",
            fileExtensions: ["sql"],
            lineComment: "--",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            highlightLanguageId: "sql",
            lspLanguageId: nil
        )
    )
}

@MainActor
final class DatabaseSQLEditorPlugin: EditorPlugin {
    let id = "DatabaseManager.sql-language"
    let name = "SQL Language Support"
    let order = 20

    func registerExtensions(into registrar: any EditorExtensionRegistrar) {
        registrar.registerLanguage(DatabaseSQLLanguageSupport.descriptor)
        registrar.registerGrammarProvider(DatabaseSQLGrammarProvider())
    }
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
