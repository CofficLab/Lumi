import EditorService

enum EditorVuePluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "vue",
        displayName: "Vue",
        fileExtensions: ["vue"],
        highlightLanguageId: "typescript",
        lspLanguageId: "vue"
    )
}
