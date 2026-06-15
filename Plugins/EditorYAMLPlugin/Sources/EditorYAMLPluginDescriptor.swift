import EditorService

enum EditorYAMLPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "yaml",
        displayName: "YAML",
        fileExtensions: ["yaml", "yml"],
        lineComment: "//",
        highlightLanguageId: "yaml"
    )
}
