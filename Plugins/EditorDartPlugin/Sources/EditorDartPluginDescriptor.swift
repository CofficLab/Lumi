import EditorService

enum EditorDartPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "dart",
        displayName: "Dart",
        fileExtensions: ["dart"],
        lineComment: "//",
        highlightLanguageId: "dart"
    )
}
