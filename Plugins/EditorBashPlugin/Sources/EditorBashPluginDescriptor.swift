import EditorService

enum EditorBashPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "bash",
        displayName: "Bash",
        fileExtensions: ["sh", "bash"],
        lineComment: "//",
        highlightLanguageId: "bash"
    )
}
