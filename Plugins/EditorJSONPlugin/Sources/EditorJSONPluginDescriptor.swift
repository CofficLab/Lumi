import EditorService

enum EditorJSONPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "json",
        displayName: "JSON",
        fileExtensions: ["json"],
        lineComment: "//",
        highlightLanguageId: "json"
    )
}
