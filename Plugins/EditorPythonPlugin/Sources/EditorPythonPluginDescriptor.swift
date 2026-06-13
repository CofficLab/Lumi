import EditorService

enum EditorPythonPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "python",
        displayName: "Python",
        fileExtensions: ["py", "pyw"],
        lineComment: "//",
        highlightLanguageId: "python"
    )
}
