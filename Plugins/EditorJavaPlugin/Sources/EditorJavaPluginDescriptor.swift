import EditorService

enum EditorJavaPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "java",
        displayName: "Java",
        fileExtensions: ["java"],
        lineComment: "//",
        highlightLanguageId: "java"
    )
}
