import EditorService

enum EditorKotlinPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "kotlin",
        displayName: "Kotlin",
        fileExtensions: ["kt", "kts"],
        lineComment: "//",
        highlightLanguageId: "kotlin"
    )
}
