import EditorService

enum EditorTOMLPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "toml",
        displayName: "TOML",
        fileExtensions: ["toml"],
        lineComment: "//",
        highlightLanguageId: "toml"
    )
}
