import EditorService

enum EditorCSharpPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "csharp",
        displayName: "C#",
        fileExtensions: ["cs"],
        lineComment: "//",
        highlightLanguageId: "c-sharp"
    )
}
