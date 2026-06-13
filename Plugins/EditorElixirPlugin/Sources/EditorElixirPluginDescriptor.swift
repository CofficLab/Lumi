import EditorService

enum EditorElixirPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "elixir",
        displayName: "Elixir",
        fileExtensions: ["ex", "exs"],
        lineComment: "//",
        highlightLanguageId: "elixir"
    )
}
