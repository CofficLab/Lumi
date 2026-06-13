import EditorService

enum EditorAgdaPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "agda",
        displayName: "Agda",
        fileExtensions: ["agda"],
        lineComment: "//",
        highlightLanguageId: "agda"
    )
}
