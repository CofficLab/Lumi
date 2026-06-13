import EditorService

enum EditorCPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "c",
        displayName: "C",
        fileExtensions: ["c", "h"],
        lineComment: "//",
        highlightLanguageId: "c"
    )
}
