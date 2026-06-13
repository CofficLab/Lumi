import EditorService

enum EditorPHPPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "php",
        displayName: "PHP",
        fileExtensions: ["php"],
        lineComment: "//",
        highlightLanguageId: "php"
    )
}
