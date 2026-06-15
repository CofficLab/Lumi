import EditorService

enum EditorZigPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "zig",
        displayName: "Zig",
        fileExtensions: ["zig"],
        lineComment: "//",
        highlightLanguageId: "zig"
    )
}
