import EditorService

enum EditorRegexPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "regex",
        displayName: "Regex",
        fileExtensions: ["regex"],
        lineComment: "//",
        highlightLanguageId: "regex"
    )
}
