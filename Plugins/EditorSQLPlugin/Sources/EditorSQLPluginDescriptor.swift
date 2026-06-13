import EditorService

enum EditorSQLPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "sql",
        displayName: "SQL",
        fileExtensions: ["sql"],
        lineComment: "//",
        highlightLanguageId: "sql"
    )
}
