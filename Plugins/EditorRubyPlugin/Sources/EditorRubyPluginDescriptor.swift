import EditorService

enum EditorRubyPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "ruby",
        displayName: "Ruby",
        fileExtensions: ["rb", "rake"],
        lineComment: "//",
        highlightLanguageId: "ruby"
    )
}
