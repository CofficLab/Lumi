import EditorService

enum EditorRustPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "rust",
        displayName: "Rust",
        fileExtensions: ["rs"],
        lineComment: "//",
        highlightLanguageId: "rust"
    )
}
